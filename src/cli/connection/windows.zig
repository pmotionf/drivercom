const std = @import("std");
const w = std.os.windows;

pub fn openPollableFile(
    dir: std.fs.Dir,
    sub_path: []const u8,
) !std.fs.File {
    const path_w = try w.sliceToPrefixedFileW(dir.fd, sub_path);
    const file: std.fs.File = .{
        .handle = w.kernel32.CreateFileW(
            path_w.span(),
            w.GENERIC_READ | w.GENERIC_WRITE,
            0,
            null,
            w.OPEN_EXISTING,
            w.FILE_FLAG_OVERLAPPED,
            null,
        ),
    };
    if (file.handle == w.INVALID_HANDLE_VALUE) {
        switch (w.GetLastError()) {
            w.Win32Error.FILE_NOT_FOUND => {
                return error.FileNotFound;
            },
            else => return error.WindowsError,
        }
    }
    return file;
}

const PollableWriterContext = struct { file: std.fs.File };
const PollableWriterError =
    w.WriteFileError ||
    w.OpenError ||
    w.Wtf8ToPrefixedFileWError ||
    w.WaitForSingleObjectError;

fn pollableWriterWriteFn(
    context: PollableWriterContext,
    bytes: []const u8,
) PollableWriterError!usize {
    var bytes_written: w.DWORD = undefined;
    var overlapped: w.OVERLAPPED = .{
        .Internal = 0,
        .InternalHigh = 0,
        .DUMMYUNIONNAME = .{
            .DUMMYSTRUCTNAME = .{
                .Offset = 0,
                .OffsetHigh = 0,
            },
        },
        .hEvent = try w.CreateEventEx(
            null,
            "",
            w.CREATE_EVENT_MANUAL_RESET,
            w.EVENT_ALL_ACCESS,
        ),
    };
    defer w.CloseHandle(overlapped.hEvent.?);
    const adjusted_len = std.math.cast(u32, bytes.len) orelse
        std.math.maxInt(u32);

    if (w.kernel32.WriteFile(
        context.file.handle,
        bytes.ptr,
        adjusted_len,
        &bytes_written,
        &overlapped,
    ) == 0) {
        switch (w.GetLastError()) {
            .INVALID_USER_BUFFER => return error.SystemResources,
            .NOT_ENOUGH_MEMORY => return error.SystemResources,
            .OPERATION_ABORTED => return error.OperationAborted,
            .NOT_ENOUGH_QUOTA => return error.SystemResources,
            .IO_PENDING => {
                try w.WaitForSingleObject(overlapped.hEvent.?, w.INFINITE);
                _ = try w.GetOverlappedResult(
                    context.file.handle,
                    &overlapped,
                    true,
                );
                return bytes.len;
            },
            .BROKEN_PIPE => return error.BrokenPipe,
            .INVALID_HANDLE => return error.NotOpenForWriting,
            .LOCK_VIOLATION => return error.LockViolation,
            .NETNAME_DELETED => return error.ConnectionResetByPeer,
            else => |err| return w.unexpectedError(err),
        }
    }
    return bytes.len;
}

pub const PollableWriter = std.io.GenericWriter(
    PollableWriterContext,
    PollableWriterError,
    pollableWriterWriteFn,
);

pub fn pollableWriter(file: std.fs.File) PollableWriter {
    return .{ .context = .{
        .file = file,
    } };
}
