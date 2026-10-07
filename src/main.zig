const std = @import("std");
const gitz = @import("gitz");
const clap = @import("clap");
const init = @import("./init.zig");

const Io = std.Io;
const SubCommands = enum {
    init,
    // @"hash-object",
};

const main_params = clap.parseParamsComptime(
    \\-h, --help  Display this help and exit.
    \\<command>
    \\
);
const main_parsers = .{
    .command = clap.parsers.enumeration(SubCommands),
};
pub const MainArgs = clap.ResultEx(clap.Help, &main_params, main_parsers);

const help_msg =
    \\ [-v | --version] [-h | --help] <command> args
    \\
    \\ These are common Git commands used in various situations:
    \\ 
    \\ start a working area
    // \\    clone      Clone a repository into a new directory
    \\    init       Create an empty Git repository or reinitialize an existing one
    // \\ 
    // \\ work on the current change
    // \\    add        Add file contents to the index
    // \\    mv         Move or rename a file, a directory, or a symlink
    // \\    restore    Restore working tree files
    // \\    rm         Remove files from the working tree and from the index
    // \\ 
    // \\ examine the history and state
    // \\    bisect     Use binary search to find the commit that introduced a bug
    // \\    diff       Show changes between commits, commit and working tree, etc
    // \\    grep       Print lines matching a pattern
    // \\    log        Show commit logs
    // \\    show       Show various types of objects
    // \\    status     Show the working tree status
    // \\ 
    // \\ grow, mark and tweak your common history
    // \\    backfill   Download missing objects in a partial clone
    // \\    branch     List, create, or delete branches
    // \\    commit     Record changes to the repository
    // \\    history    EXPERIMENTAL: Rewrite history
    // \\    merge      Join two or more development histories together
    // \\    rebase     Reapply commits on top of another base tip
    // \\    reset      Set `HEAD` or the index to a known state
    // \\    switch     Switch branches
    // \\    tag        Create, list, delete or verify tags
    // \\ 
    // \\ collaborate (see also: git help workflows)
    // \\    fetch      Download objects and refs from another repository
    // \\    pull       Fetch from and integrate with another repository or a local branch
    // \\    push       Update remote refs along with associated objects
    \\
;

fn print_help(exe_name: []const u8, io: std.Io) !void {
    const stdout = std.Io.File.stdout();
    try stdout.writeStreamingAll(io, exe_name);
    try stdout.writeStreamingAll(io, " ");
    try stdout.writeStreamingAll(io, help_msg);
}

pub fn main(in: std.process.Init) !void {
    var iter = try in.minimal.args.iterateAllocator(in.gpa);
    defer iter.deinit();

    const exe_name = std.fs.path.basename(iter.next() orelse unreachable);

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &main_params, main_parsers, &iter, .{
        .diagnostic = &diag,
        .allocator = in.gpa,
        .terminating_positional = 0,
    }) catch |err| {
        try diag.reportToFile(in.io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try print_help(exe_name, in.io);
        return;
    }

    const command = res.positionals[0] orelse {
        try print_help(exe_name, in.io);
        return error.MissingCommand;
    };
    switch (command) {
        .init => try init.main(in.io, in.gpa, &iter),
        // .@"hash-object" => try init.main(in.io, in.gpa, &iter, res),
    }
}
