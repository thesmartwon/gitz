git_dir: []const u8,
// For worktrees or submodules
common_dir: []const u8,
prefix: []const u8,

config: Config,

// By default, git config will read configuration options from multiple files:
//
//      $(prefix)/etc/gitconfig
//          System-wide configuration file.
//
//                                                                                  $XDG_CONFIG_HOME/git/config, ~/.gitconfig
//          User-specific configuration files. When the XDG_CONFIG_HOME environment variable  is  not  set  or  empty,
//          $HOME/.config/ is used as $XDG_CONFIG_HOME.
//
//          These  are also called "global" configuration files. If both files exist, both files are read in the order
//          given above.
//
//      $GIT_DIR/config
//          Repository specific configuration file.
//
//      $GIT_DIR/config.worktree
//          This is optional and is only searched when extensions.worktreeConfig is present in $GIT_DIR/config.
//
//      You may also provide additional configuration parameters when running any git command by using the -c  option.
//      See git(1) for details.
//
//      Options  will  be read from all of these files that are available. If the global or the system-wide configura‐
//      tion files are missing or unreadable they will be ignored. If the repository configuration file is missing  or
//      unreadable,  git  config will exit with a non-zero error code. An error message is produced if the file is un‐
//      readable, but not if it is missing.
//
//      The files are read in the order given above, with last value found taking precedence over values read earlier.
//      When multiple values are taken then all values of a key from all files will be used.
//
//      By default, options are only written to the repository specific configuration file. Note that  this  also  af‐
//      fects options like set and unset. git config will only ever change one file at a time.
//
//      You  can  limit  which configuration sources are read from or written to by specifying the path of a file with
//      the --file option, or by specifying a configuration scope with --system, --global, --local, or --worktree. For
//      more, see the section called “OPTIONS” above.
const Config = struct {
    repository_format_version: u8 = 0,
    file_mode: bool = true,
    bare: bool = false,
    log_all_ref_updates: bool = true,
    symlinks: bool = false,

    const name_map = .{
        .{ "repository_format_version", "repositoryformatversion" },
        .{ "file_mode", "filemode" },
        .{ "bare", "bare" },
        .{ "log_all_ref_updates", "logallrefupdates" },
    };

    fn writeRenameHandler(comptime header: ?[]const u8, comptime field_name: ?[]const u8) ?[]const u8 {
        if (header == null or !std.mem.eql(u8, header.?, "core") or field_name == null) return field_name;

        inline for (name_map) |kv| if (std.mem.eql(u8, field_name.?, kv[0])) return kv[1];

        return field_name;
    }

    fn readRenameHandler(arena: std.mem.Allocator, field: zigini.IniField) ?zigini.IniField {
        _ = arena;
        inline for (name_map) |kv| {
            if (std.mem.eql(u8, field.key, kv[1])) {
                std.debug.print("HANDLED {s}\n", .{kv[1]});
                return .{
                    .header = "",
                    .key = kv[0],
                    .value = field.value,
                };
            }
        }
        return field;
    }

    pub fn write(self: @This(), io: std.Io, git_dir: std.Io.Dir, alloc: std.mem.Allocator) !void {
        const f = try git_dir.createFile(io, "config", .{});
        var fbuf: [std.heap.pageSize()]u8 = undefined;
        var fwriter = f.writer(io, &fbuf);
        const writer = &fwriter.interface;

        var config_writer = zigini.Ini(@This()).init(alloc);
        defer config_writer.deinit();
        try zigini.writeFromStruct(self, writer, "core", .{
            .renameHandler = writeRenameHandler,
        });

        try writer.flush();
    }

    pub fn read(alloc: std.mem.Allocator, io: std.Io, git_dir: std.Io.Dir) !@This() {
        const f = try git_dir.openFile(io, "config", .{});
        defer f.close(io);

        var fbuf: [std.heap.pageSize()]u8 = undefined;
        var freader = f.reader(io, &fbuf);
        const reader = &freader.interface;

        var config_reader = zigini.Ini(@This()).init(alloc);
        defer config_reader.deinit();

        return try config_reader.readToStruct(reader, .{
            .fieldHandler = readRenameHandler,
        });
    }
};

pub fn init(io: std.Io, gpa: std.mem.Allocator, args: InitArgs) !@This() {
    const cwd = std.Io.Dir.cwd();
    const git_dir_path = try std.fs.path.resolve(gpa, &.{ args.positionals[0] orelse ".", ".git" });
    const config: Config = .{};

    {
        // init common directories
        try std.Io.Dir.createDirPath(cwd, io, git_dir_path);
        const git_dir = try std.Io.Dir.openDir(cwd, io, git_dir_path, .{});
        defer std.Io.Dir.close(git_dir, io);
        try config.write(io, git_dir, gpa);
    }

    return .{
        .git_dir = git_dir_path,
        .common_dir = "",
        .prefix = "",
        .config = config,
    };
}

pub fn open(io: std.Io, gpa: std.mem.Allocator) !@This() {
    const cwd = std.Io.Dir.cwd();
    const git_dir_path = try std.fs.path.resolve(gpa, &.{ ".", ".git" });
    const git_dir = try std.Io.Dir.openDir(cwd, io, git_dir_path, .{});
    const config = try Config.read(gpa, io, git_dir);

    return .{
        .git_dir = git_dir_path,
        .common_dir = "",
        .prefix = "",
        .config = config,
    };
}

pub fn deinit(self: @This(), gpa: std.mem.Allocator) void {
    gpa.free(self.git_dir);
    gpa.free(self.common_dir);
    gpa.free(self.prefix);
}

const std = @import("std");
const InitArgs = @import("./init.zig").Args;
const zigini = @import("ini");
