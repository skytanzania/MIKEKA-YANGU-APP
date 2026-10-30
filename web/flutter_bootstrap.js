{{flutter_js}}
{{flutter_build_config}}

// No service worker: it kept serving the old version after an update.
// The server's cache rules (.htaccess) keep loading fast instead.
_flutter.loader.load();
