const std = @import("std");
const mem = std.mem;

const usage =
    \\
    \\Usage: req [METHOD] URL
    \\  
    \\  METHOD
    \\        The HTTP method to be used for the request (GET, POST, PUT, DELETE, ...).
    \\        By default req uses GET method.
    \\  
    \\  URL
    \\        Default scheme is 'http://' if the URL does not include any.
    \\  
    \\  General Options:
    \\  
    \\    -h, --help       Print command-specific usage
    \\  
;

const Request = struct {
    host: []const u8,
    port: u16,
    path: []const u8,
};

pub fn main() anyerror!u8 {
    var method: []const u8 = "GET";
    const stdout = std.io.getStdOut().writer();
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = &arena.allocator;

    var args = std.process.args();
    _ = args.skip();

    var firstArg = try (args.next(alloc) orelse {
        std.log.err("no method or address provided\n", .{});
        try stdout.print("{}\r\n", .{usage});
        return error.InvalidArgs;
    });

    if (std.mem.eql(u8, firstArg, "-h") or std.mem.eql(u8, firstArg, "--help")) {
        try stdout.print("{}\r\n", .{usage});
        return 0;
    }

    const url = try (args.next(alloc)) orelse firstArg;
    if (!std.mem.eql(u8, firstArg, url)) {
        method = firstArg;
    }

    const request = try parseUrl(alloc, url);
    var cn = try std.net.tcpConnectToHost(alloc, request.host, request.port);
    defer cn.close();

    var buffer: [256]u8 = undefined;
    const base_http = "{} {} HTTP/1.1\r\nHost: {}\r\nConnection: close\r\n\r\n";
    var msg = try std.fmt.bufPrint(&buffer, base_http, .{
        method,
        request.path,
        request.host,
    });

    _ = try cn.write(msg);

    const maxBufLen = 1024;
    var buf: [maxBufLen]u8 = undefined;
    var total_bytes: usize = 0;

    while (true) {
        const byte_count = try cn.read(&buf);
        if (byte_count == 0) break;

        try stdout.print("{}", .{buf[0..byte_count]});

        buf = undefined;
        total_bytes += byte_count;
    }

    return 0;
}

fn parseUrl(allocator: *mem.Allocator, url: []u8) anyerror!Request {
    const SLASH = "/";
    const COLON = ":";
    const COLONSLASH = "://";
    var port: []const u8 = "80";
    var path: []const u8 = SLASH;
    var hostStart: usize = 0;
    var hostEnd: usize = url.len;

    var start: usize = 0;
    var doubleSlashIdx = mem.indexOf(u8, url[0..], COLONSLASH);

    if (doubleSlashIdx != null) {
        start += doubleSlashIdx.? + COLONSLASH.len;
        hostStart = start;

        if (mem.eql(u8, url[0..doubleSlashIdx.?], "https")) port = "443";
    }

    var portColon = mem.indexOf(u8, url[start..], COLON);

    if (portColon != null) {
        hostEnd = start + portColon.?;
        start += portColon.? + 1;

        var pathSlash = mem.indexOf(u8, url[start..], SLASH);
        if (pathSlash != null) {
            port = url[start..(pathSlash.? + start)];
            path = url[pathSlash.? + start ..];
        } else {
            port = url[start..];
        }
    } else {
        var pathSlash = mem.indexOf(u8, url[start..], SLASH);
        if (pathSlash != null) {
            hostEnd = start + pathSlash.?;
            path = url[start + pathSlash.? ..];
        }
    }

    var host = url[hostStart..hostEnd];

    return Request{
        .host = host,
        .port = try std.fmt.parseInt(u16, port, 10),
        .path = path,
    };
}
