# /etc/varnish/default.vcl

vcl 4.1;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

sub vcl_recv {
    # Enable HTTP/1.1 keepalive
    set req.http.Connection = "";

    # Normalize request headers
    if (req.http.Accept-Encoding) {
        if (req.url ~ "\.(jpg|jpeg|png|gif|gz|tgz|bz2|tbz|mp3|ogg|woff2?|eot|ttf)$") {
            unset req.http.Accept-Encoding;
        } elsif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            unset req.http.Accept-Encoding;
        }
    }

    # Cache static files aggressively
    if (req.url ~ "\.(css|js|png|jpg|jpeg|gif|ico|svg|woff2?|ttf|eot|mp[34]|webm|ogg)$") {
        unset req.http.Cookie;
        return (hash);
    }

    # Strip cookies for static content that doesn't need them
    if (req.url ~ "^[^?]*\.(?:css|js|jpg|jpeg|gif|png|ico|woff2?|ttf|eot|svg)(?:\?.*|)$") {
        unset req.http.Cookie;
    }

    # Cache non-authenticated pages by default
    if (req.http.Authorization || req.http.Cookie) {
        return (pass);
    }

    # Large file download support (chunked transfer)
    if (req.url ~ "^/downloads/") {
        set req.backend_hint = default;
        return (hash);
    }

    # Enable Edge Side Includes (ESI) processing
    if (req.esi_level > 0) {
        set req.http.Surrogate-Capability = "ESI/1.0";
    }

    # Grace mode to serve stale content when backend is down
    set req.http.grace = "none";
    
    return (hash);
}

sub vcl_backend_response {
    # Enable grace mode
    set beresp.grace = 6h;
    
    # Default TTL for all objects
    set beresp.ttl = 14400s; # 4 hours
    
    # Cache static files longer
    if (bereq.url ~ "\.(css|js|png|jpg|jpeg|gif|ico|svg|woff2?|ttf|eot|mp[34]|webm|ogg)$") {
        set beresp.ttl = 30d;
        set beresp.http.Cache-Control = "public, max-age=2592000";
    }
    
    # Cache API responses
    if (bereq.url ~ "^/api/") {
        set beresp.ttl = 60s;
    }
    
    # Enable streaming for large files
    if (beresp.http.Content-Length ~ "[0-9]{7,}") {
        set beresp.do_stream = true;
    }
    
    # Compress objects before storing
    if (beresp.http.content-type ~ "text|javascript|json|css|xml") {
        set beresp.do_gzip = true;
    }
    
    # Enable ESI processing where supported
    if (beresp.http.Surrogate-Control ~ "ESI/1.0") {
        set beresp.do_esi = true;
    }
    
    # Don't cache 5xx responses
    if (beresp.status >= 500) {
        set beresp.uncacheable = true;
        set beresp.ttl = 1s;
    }
}

sub vcl_deliver {
    # Add cache hit/miss header for debugging
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }
    
    # Remove some headers to save bandwidth
    unset resp.http.Via;
    unset resp.http.X-Varnish;
    unset resp.http.Server;
    unset resp.http.X-Powered-By;
    
    # Add cache control headers for proxies
    if (resp.http.Cache-Control ~ "max-age") {
        set resp.http.Age = resp.http.Age;
    }
}

sub vcl_hit {
    # Serve stale content when backends are down
    if (obj.ttl >= 0s) {
        return (deliver);
    }
    
    if (std.healthy(req.backend_hint)) {
        if (obj.ttl + 300s > 0s) {
            return (deliver);
        } else {
            return (restart);
        }
    } else {
        if (obj.ttl + obj.grace > 0s) {
            return (deliver);
        } else {
            return (restart);
        }
    }
}