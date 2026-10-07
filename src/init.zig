const std = @import("std");
const clap = @import("clap");

pub fn main(
    io: std.Io,
    gpa: std.mem.Allocator,
    iter: *std.process.Args.Iterator,
) !void {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help  Display this help and exit.
        \\-a, --add   Add the two numbers
        \\-s, --sub   Subtract the two numbers
        \\<isize>
        \\<isize>
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parseEx(clap.Help, &params, clap.parsers.default, iter, .{
        .diagnostic = &diag,
        .allocator = gpa,
    }) catch |err| {
        try diag.reportToFile(io, .stderr(), err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        std.debug.print("--help\n", .{});
        return;
    }

    const a = res.positionals[0] orelse return error.MissingArg1;
    const b = res.positionals[1] orelse return error.MissingArg1;
    if (res.args.add != 0)
        std.debug.print("added: {}\n", .{a + b});
    if (res.args.sub != 0)
        std.debug.print("subtracted: {}\n", .{a - b});
}
