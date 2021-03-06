{ stdenv, lib, fetchurl, writeText, pkgconfig, perl
, http2Support ? true, nghttp2
, idnSupport ? false, libidn ? null
, ldapSupport ? false, openldap ? null
, zlibSupport ? true, zlib ? null
, sslSupport ? zlibSupport, openssl ? null
, gnutlsSupport ? false, gnutls ? null
, wolfsslSupport ? false, wolfssl ? null
, scpSupport ? zlibSupport && !stdenv.isSunOS && !stdenv.isCygwin, libssh2 ? null
, gssSupport ? !stdenv.hostPlatform.isWindows, libkrb5 ? null
, c-aresSupport ? false, c-ares ? null
, brotliSupport ? false, brotli ? null
}:

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Nixpkgs as
# files.

assert http2Support -> nghttp2 != null;
assert idnSupport -> libidn != null;
assert ldapSupport -> openldap != null;
assert zlibSupport -> zlib != null;
assert sslSupport -> openssl != null;
assert !(gnutlsSupport && sslSupport);
assert !(gnutlsSupport && wolfsslSupport);
assert !(sslSupport && wolfsslSupport);
assert gnutlsSupport -> gnutls != null;
assert wolfsslSupport -> wolfssl != null;
assert scpSupport -> libssh2 != null;
assert c-aresSupport -> c-ares != null;
assert brotliSupport -> brotli != null;
assert gssSupport -> libkrb5 != null;

stdenv.mkDerivation rec {
  pname = "curl";
  version = "7.72.0";

  src = fetchurl {
    urls = [
      "https://curl.haxx.se/download/${pname}-${version}.tar.bz2"
      "https://github.com/curl/curl/releases/download/${lib.replaceStrings ["."] ["_"] pname}-${version}/${pname}-${version}.tar.bz2"
    ];
    sha256 = "1vq3ay87vayfrv67l7s7h79nm7gwdqhidki0brv5jahhch49g4dd";
  };

  outputs = [ "bin" "dev" "out" "man" "devdoc" ];
  separateDebugInfo = stdenv.isLinux;

  enableParallelBuilding = true;

  nativeBuildInputs = [ pkgconfig perl ];

  # Zlib and OpenSSL must be propagated because `libcurl.la' contains
  # "-lz -lssl", which aren't necessary direct build inputs of
  # applications that use Curl.
  propagatedBuildInputs = with stdenv.lib;
    optional http2Support nghttp2 ++
    optional idnSupport libidn ++
    optional ldapSupport openldap ++
    optional zlibSupport zlib ++
    optional gssSupport libkrb5 ++
    optional c-aresSupport c-ares ++
    optional sslSupport openssl ++
    optional gnutlsSupport gnutls ++
    optional wolfsslSupport wolfssl ++
    optional scpSupport libssh2 ++
    optional brotliSupport brotli;

  patches = [
    (writeText "setup_User-Agent_at_pretransfer.patch" ''
      diff --git a/lib/transfer.c b/lib/transfer.c
      index bfd0218fe..ea37f741c 100644
      --- a/lib/transfer.c
      +++ b/lib/transfer.c
      @@ -1532,6 +1532,20 @@ CURLcode Curl_pretransfer(struct Curl_easy *data)
           Curl_hsts_loadcb(data, data->hsts);
         }
       
      +  /*
      +   * Set user-agent. Used for HTTP, but since we can attempt to tunnel
      +   * basically anything through a http proxy we can't limit this based on
      +   * protocol.
      +   */
      +  if(data->set.str[STRING_USERAGENT]) {
      +    Curl_safefree(data->state.aptr.uagent);
      +    data->state.aptr.uagent =
      +      aprintf("User-Agent: %s\r\n", data->set.str[STRING_USERAGENT]);
      +    if(!data->state.aptr.uagent)
      +      return CURLE_OUT_OF_MEMORY;
      +  }
      +
      +  data->req.headerbytecount = 0;
         return result;
       }
       
      diff --git a/lib/url.c b/lib/url.c
      index 2b0ba87ba..3af3608d1 100644
      --- a/lib/url.c
      +++ b/lib/url.c
      @@ -3940,20 +3940,6 @@ CURLcode Curl_setup_conn(struct connectdata *conn,
            lingering set from a previous invoke */
         conn->bits.proxy_connect_closed = FALSE;
       #endif
      -  /*
      -   * Set user-agent. Used for HTTP, but since we can attempt to tunnel
      -   * basically anything through a http proxy we can't limit this based on
      -   * protocol.
      -   */
      -  if(data->set.str[STRING_USERAGENT]) {
      -    Curl_safefree(data->state.aptr.uagent);
      -    data->state.aptr.uagent =
      -      aprintf("User-Agent: %s\r\n", data->set.str[STRING_USERAGENT]);
      -    if(!data->state.aptr.uagent)
      -      return CURLE_OUT_OF_MEMORY;
      -  }
      -
      -  data->req.headerbytecount = 0;
       
       #ifdef CURL_DO_LINEEND_CONV
         data->state.crlf_conversions = 0; /* reset CRLF conversion counter */
    '')
  ];

  # for the second line see https://curl.haxx.se/mail/tracker-2014-03/0087.html
  preConfigure = ''
    sed -e 's|/usr/bin|/no-such-path|g' -i.bak configure
    rm src/tool_hugehelp.c
  '';

  configureFlags = [
      # Disable default CA bundle, use NIX_SSL_CERT_FILE or fallback
      # to nss-cacert from the default profile.
      "--without-ca-bundle"
      "--without-ca-path"
      # The build fails when using wolfssl with --with-ca-fallback
      ( if wolfsslSupport then "--without-ca-fallback" else "--with-ca-fallback")
      "--disable-manual"
      ( if sslSupport then "--with-ssl=${openssl.dev}" else "--without-ssl" )
      ( if gnutlsSupport then "--with-gnutls=${gnutls.dev}" else "--without-gnutls" )
      ( if scpSupport then "--with-libssh2=${libssh2.dev}" else "--without-libssh2" )
      ( if ldapSupport then "--enable-ldap" else "--disable-ldap" )
      ( if ldapSupport then "--enable-ldaps" else "--disable-ldaps" )
      ( if idnSupport then "--with-libidn=${libidn.dev}" else "--without-libidn" )
      ( if brotliSupport then "--with-brotli" else "--without-brotli" )
    ]
    ++ stdenv.lib.optional wolfsslSupport "--with-wolfssl=${wolfssl.dev}"
    ++ stdenv.lib.optional c-aresSupport "--enable-ares=${c-ares}"
    ++ stdenv.lib.optional gssSupport "--with-gssapi=${libkrb5.dev}"
       # For the 'urandom', maybe it should be a cross-system option
    ++ stdenv.lib.optional (stdenv.hostPlatform != stdenv.buildPlatform)
       "--with-random=/dev/urandom"
    ++ stdenv.lib.optionals stdenv.hostPlatform.isWindows [
      "--disable-shared"
      "--enable-static"
    ];

  CXX = "${stdenv.cc.targetPrefix}c++";
  CXXCPP = "${stdenv.cc.targetPrefix}c++ -E";

  doCheck = false; # expensive, fails

  postInstall = ''
    moveToOutput bin/curl-config "$dev"

    # Install completions
    make -C scripts install
  '' + stdenv.lib.optionalString scpSupport ''
    sed '/^dependency_libs/s|${libssh2.dev}|${libssh2.out}|' -i "$out"/lib/*.la
  '' + stdenv.lib.optionalString gnutlsSupport ''
    ln $out/lib/libcurl.so $out/lib/libcurl-gnutls.so
    ln $out/lib/libcurl.so $out/lib/libcurl-gnutls.so.4
    ln $out/lib/libcurl.so $out/lib/libcurl-gnutls.so.4.4.0
  '';

  passthru = {
    inherit sslSupport openssl;
  };

  meta = with stdenv.lib; {
    description = "A command line tool for transferring files with URL syntax";
    homepage    = "https://curl.haxx.se/";
    license = licenses.curl;
    maintainers = with maintainers; [ lovek323 ];
    platforms = platforms.all;
  };
}
