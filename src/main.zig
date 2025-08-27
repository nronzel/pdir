const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const expect = std.testing.expect;
const expectEqualStrings = std.testing.expectEqualStrings;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const MAX_DEPTH: u7 = 10;
const DEFAULT_DEPTH: u7 = 2;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Initialize output buffer with 1MB capacity, will grow automatically.
    var output = try std.io.Writer.Allocating.initCapacity(allocator, 1 << 20);
    defer output.deinit();
    var stdout = &output.writer;

    if (args.len > 1 and (mem.eql(u8, args[1], "-h") or mem.eql(u8, args[1], "--help"))) {
        try printUsage(stdout);
        return;
    }

    const parsed_args = try ParseArgs(args);

    const absolute_path = try getAbsolutePath(allocator, parsed_args.dir_path);
    defer allocator.free(absolute_path);

    var counts = Counts{ .dirs = 0, .files = 0, .sym_links = 0, .other = 0 };
    try stdout.print("{s}\n", .{absolute_path});
    const current_depth: u7 = 0;
    try printDirectory(
        allocator,
        absolute_path,
        parsed_args.max_depth,
        current_depth,
        stdout,
        &counts,
    );
    try stdout.print("\n{d} directories, {d} files, {d} sym-links, {d} other\n", .{
        counts.dirs,
        counts.files,
        counts.sym_links,
        counts.other,
    });

    try std.fs.File.stdout().writeAll(output.written());
}

// Counts keeps track of the number of directories, files, symlinks, and others.
// other is defined below.
const Counts = struct {
    dirs: u16,
    files: u16,
    sym_links: u16,
    other: u16,
};

// only tracking files, dirs, and sym-links. "other" represents the following:
//  - block_device
//  - character_device
//  - named_pipe
//  - unix_domain_socket
//  - whiteout
//  - door
//  - event_port
//  - unknown
const EntryType = enum {
    is_file,
    is_dir,
    is_symlink,
    is_other,
};

// Entry represents an entry found in the traversal. It holds the name and an
// enum representing the type.
const Entry = struct {
    name: []const u8,
    entry_t: EntryType,
};

// Recursively navigates the provided directory for the provided depth. Keeps
// count of dirs, files, and sym-links and prints the resulting file structure
// and counts.
fn printDirectory(
    allocator: mem.Allocator,
    path: []const u8,
    max_depth: u7,
    current_depth: u7,
    writer: anytype,
    counts: *Counts,
) !void {
    if (current_depth >= max_depth) return;
    var dir = try fs.openDirAbsolute(path, .{ .iterate = true });
    defer dir.close();

    // store entries in ArrayList for sorting
    var entries = std.ArrayList(Entry).empty;
    defer {
        for (entries.items) |entry| {
            allocator.free(entry.name);
        }
        entries.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const entry_type = switch (entry.kind) {
            .directory => EntryType.is_dir,
            .sym_link => EntryType.is_symlink,
            .file => EntryType.is_file,
            else => EntryType.is_other,
        };

        try entries.append(allocator, Entry{
            .name = try allocator.dupe(u8, entry.name),
            .entry_t = entry_type,
        });
    }

    // Sort entries alphabetically
    mem.sort(Entry, entries.items, {}, entryLessThan);

    // Print sorted entries with proper level of indentation. Dirs have a
    // directory icon and everything else gets a file icon.
    for (entries.items) |entry| {
        try printIndentation(current_depth, writer);
        const symbol = switch (entry.entry_t) {
            .is_dir => "📁",
            else => "📄",
        };
        try writer.print("{s} {s}\n", .{ symbol, entry.name });
        switch (entry.entry_t) {
            .is_dir => {
                counts.dirs += 1;
                if (current_depth < max_depth - 1) {
                    var path_buffer: [fs.max_path_bytes]u8 = undefined;
                    const new_path = try std.fmt.bufPrint(&path_buffer, "{s}{c}{s}", .{
                        path,
                        fs.path.sep,
                        entry.name,
                    });
                    try printDirectory(
                        allocator,
                        new_path,
                        max_depth,
                        current_depth + 1,
                        writer,
                        counts,
                    );
                }
            },
            .is_symlink => counts.sym_links += 1,
            .is_file => counts.files += 1,
            else => counts.other += 1,
        }
    }
}

const ParsedArgs = struct {
    dir_path: []const u8,
    max_depth: u7,
};

fn ParseArgs(args: []const []const u8) !ParsedArgs {
    var result = ParsedArgs{
        .dir_path = ".",
        .max_depth = DEFAULT_DEPTH,
    };

    switch (args.len) {
        1 => {}, // default
        2 => {
            if (std.fmt.parseInt(u7, args[1], 10)) |depth| {
                result.max_depth = @min(depth, MAX_DEPTH);
            } else |_| {
                result.dir_path = args[1];
            }
        },
        3 => {
            result.dir_path = args[1];
            result.max_depth = @min(try std.fmt.parseInt(u7, args[2], 10), MAX_DEPTH);
        },
        else => return error.TooManyArguments,
    }

    return result;
}

fn getAbsolutePath(allocator: mem.Allocator, path: []const u8) ![]const u8 {
    return if (fs.path.isAbsolute(path))
        try allocator.dupe(u8, path)
    else
        try fs.cwd().realpathAlloc(allocator, path);
}

// Compares entry names alphabetically. Safely handles hidden files and directories.
fn entryLessThan(context: void, a: Entry, b: Entry) bool {
    _ = context;
    const n1 = if (a.name[0] == '.') a.name[1..] else a.name;
    const n2 = if (b.name[0] == '.') b.name[1..] else b.name;
    return std.ascii.lessThanIgnoreCase(n1, n2);
}

fn printIndentation(level: u8, writer: anytype) !void {
    for (0..level) |_| {
        try writer.writeAll("    ");
    }
}

fn printUsage(writer: anytype) !void {
    try writer.print(
        \\
        \\Usage: {s} [directory] [max_depth]
        \\
        \\Arguments:
        \\  directory   The directory to list (default: current working directory)
        \\  max_depth   Maximum depth to traverse (default: 2)
        \\
        \\Options:
        \\  -h, --help  Show this help message
        \\
    , .{std.os.argv[0]});
}

test "printIndentation" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    try printIndentation(1, writer);
    try expectEqualStrings("    ", fbs.getWritten());

    fbs.reset();
    try printIndentation(3, writer);
    try expectEqualStrings("            ", fbs.getWritten());

    fbs.reset();
    try printIndentation(0, writer);
    try expectEqualStrings("", fbs.getWritten());
}

test "ParseArgs" {
    // Test case 1: No arguments (default values)
    {
        const args = [_][]const u8{"program"};
        const result = try ParseArgs(&args);
        try expectEqual(@as(u4, 2), result.max_depth);
        try expectEqualStrings(".", result.dir_path);
    }

    // Test case 2: One argument (integer)
    {
        const args = [_][]const u8{ "program", "5" };
        const result = try ParseArgs(&args);
        try expectEqual(@as(u4, 5), result.max_depth);
        try expectEqualStrings(".", result.dir_path);
    }

    // Test case 3: One argument (directory path)
    {
        const args = [_][]const u8{ "program", "/home/user" };
        const result = try ParseArgs(&args);
        try expectEqual(@as(u4, 2), result.max_depth);
        try expectEqualStrings("/home/user", result.dir_path);
    }

    // Test case 4: Two arguments (directory path and max depth)
    {
        const args = [_][]const u8{ "program", "/home/user", "3" };
        const result = try ParseArgs(&args);
        try expectEqual(@as(u4, 3), result.max_depth);
        try expectEqualStrings("/home/user", result.dir_path);
    }

    // Test case 5: Invalid max depth (should return error)
    {
        const args = [_][]const u8{ "program", "/home/user", "invalid" };
        try expectError(error.InvalidCharacter, ParseArgs(&args));
    }
}

test "printDirectory" {
    const allocator = std.testing.allocator;

    // Create a temporary directory
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create test directory structure
    try tmp_dir.dir.makeDir("dir1");
    try tmp_dir.dir.makeDir("dir2");
    try tmp_dir.dir.makeDir("dir1/subdir");
    _ = try tmp_dir.dir.createFile("file1.txt", .{});
    _ = try tmp_dir.dir.createFile("dir1/file2.txt", .{});
    _ = try tmp_dir.dir.createFile("dir2/file3.txt", .{});

    // Create a buffer to capture the output
    var buffer: [2048]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    // Initialize counts
    var counts = Counts{ .dirs = 0, .files = 0, .sym_links = 0, .other = 0 };

    // Get the real path of the temporary directory
    const real_path = try tmp_dir.dir.realpathAlloc(allocator, ".");
    defer allocator.free(real_path);

    // Call print_directory
    try printDirectory(allocator, real_path, 3, 0, writer, &counts);

    // Check the output
    const output = fbs.getWritten();
    try expect(std.mem.indexOf(u8, output, "📁 dir1") != null);
    try expect(std.mem.indexOf(u8, output, "📁 dir2") != null);
    try expect(std.mem.indexOf(u8, output, "📁 subdir") != null);
    try expect(std.mem.indexOf(u8, output, "📄 file1.txt") != null);
    try expect(std.mem.indexOf(u8, output, "📄 file2.txt") != null);
    try expect(std.mem.indexOf(u8, output, "📄 file3.txt") != null);

    // Check the counts
    try expectEqual(@as(u16, 3), counts.dirs);
    try expectEqual(@as(u16, 3), counts.files);
    try expectEqual(@as(u16, 0), counts.sym_links);
    try expectEqual(@as(u16, 0), counts.other);
}
