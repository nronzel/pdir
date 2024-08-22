# pdir

pdir ("pretty directory" or "print directory") is a lightweight, Zig-based
implementation of the Linux tree command. It provides a visual representation
of directory structures, using 📁 icons for directories and 📄 icons for files.

## Features

- Customizable directory path and depth
- Intuitive visual representation of file system structures
- Provides count of directories, files, sym-links, and others
- Simple and efficient command-line interface

## Requirements

This was made with Zig version 0.14.0-dev.130+cb308ba3a

[Zig](https://ziglang.org/download/) - master release (2024-06-28 or later)

> [!CAUTION]
> This program was only tested on Linux.

## Installation

1. Clone the repository:

```sh
git clone https://github.com/nronzel/pdir
cd pdir
```

2. Build the binary:

```sh
zig build -Doptimize=ReleaseSafe
```

OR

[Download the latest release binary](https://github.com/nronzel/pdir/releases/latest)

Be sure to add the binary to a directory that is on your `$PATH`. See [quick setup](#quick-setup)

> [!TIP]
> If you chose to download one of the prebuilt releases, feel free to rename the
> binary to `pdir`, or set up an alias in your `.bashrc`, `.zshrc`, etc. to
> make it easier to run.

## Usage

```sh
pdir [directory] [depth]
```

- directory: Optional. Path to the directory you want to visualize. Defaults to
  the current working directory.
- depth: Optional. Maximum depth of directory traversal. Defaults to 2.

### Examples

```sh
pdir ~/Documents 3
```

This command will display the directory structure of ~/Documents up to a depth
of 3 levels.

```sh
pdir
```

This command will display the directory structure of the current working
directory up to a depth of 2 levels.

## Quick Setup

To use pdir from anywhere in your terminal:

1. Copy the binary to a directory that is in your PATH:

```sh
cp ./zig-out/bin/pdir ~/.local/bin/
```

On Linux, you can view the directories in your path by running:

```sh
echo $PATH
```

Now you can run pdir from any location in your terminal.

## Testing

Run the included tests:

```sh
zig test src/main.zig
```

## About

I write this re-implementation of `tree` any time I am learning a new language
as I feel it helps me get a good grasp of some of the basics of the language
(i.e. working with strings, files & directories, directory traversal,
recursion, comparisons, sorting, argument parsing, etc.).

Overall this was a joy to build. I'm sure there are plenty of areas for
improvement in my implementation and use of the language, but as a first project
after going through [Ziglings](https://codeberg.org/ziglings/exercises/) I am
happy with what I have.

As for Zig, I am really liking the language and I'm excited to follow its
development as it approaches v1.0 and beyond.

Coming from mostly writing Go for the past year, having proper enums, unions,
tagged unions, and optionals is like a breath of fresh air.

I will definitely be using more Zig in my side projects!

> [!NOTE]
> I developed this on my local self-hosted forgejo and uploaded to Github later,
> hence the lack of commit history.
