{ stdenv
, fetchFromGitHub
, writeText
, cmake
, pkgconfig
, boost
, ffmpeg_4
, graphicsmagick
, libconfig
, taglib
, pstreams
, wt, useMinimalWt ? false
}:

let
  ffmpeg = ffmpeg_4;

  # Wt with the minimum set of optional dependencies required for LMS
  wt-minimal = wt.override {
    # Docs not needed
    doxygen = null;
    # Graphics libraries not needed
    glew = null; libharu = null; pango = null; graphicsmagick = null;
    # LMS uses only sqlite
    firebird = null; libmysqlclient = null; postgresql = null;
    # Qt not used
    qt48Full = null;
  };

  wt-lms = if useMinimalWt then wt-minimal else wt;
in

stdenv.mkDerivation rec {
  pname = "lms";
  version = "3.12.1";

  src = fetchFromGitHub {
    owner = "epoupon";
    repo = pname;
    rev = "v${version}";
    sha256 = "1jmqd7yhkaqdbyx0idl1by2j09i0vggm0xh1h3swav4flc3jy6rl";
  };

  enableParallelBuilding = true;

  nativeBuildInputs = [ cmake pkgconfig ];
  buildInputs = [
    boost.dev ffmpeg.dev graphicsmagick libconfig taglib pstreams wt-lms
  ];

  patches = [
    (writeText "hardcode-dependency-paths.patch" ''
      diff --git a/src/libs/av/impl/AvTranscoder.cpp b/src/libs/av/impl/AvTranscoder.cpp
      index fd6576f..420cb64 100644
      --- a/src/libs/av/impl/AvTranscoder.cpp
      +++ b/src/libs/av/impl/AvTranscoder.cpp
      @@ -38,7 +38,7 @@ static std::filesystem::path	ffmpegPath;
       void
       Transcoder::init()
       {
      -	ffmpegPath = ServiceProvider<IConfig>::get()->getPath("ffmpeg-file", "/usr/bin/ffmpeg");
      +	ffmpegPath = ServiceProvider<IConfig>::get()->getPath("ffmpeg-file", "${ffmpeg.bin}/bin/ffmpeg");
       	if (!std::filesystem::exists(ffmpegPath))
       		throw LmsException {"File '" + ffmpegPath.string() + "' does not exist!"};
       }
      diff --git a/src/lms/main.cpp b/src/lms/main.cpp
      index 44e3ea6..9fbde9c 100644
      --- a/src/lms/main.cpp
      +++ b/src/lms/main.cpp
      @@ -44,7 +44,7 @@ std::vector<std::string> generateWtConfig(std::string execPath)
       	const std::filesystem::path wtConfigPath {ServiceProvider<IConfig>::get()->getPath("working-dir") / "wt_config.xml"};
       	const std::filesystem::path wtLogFilePath {ServiceProvider<IConfig>::get()->getPath("log-file", "/var/log/lms.log")};
       	const std::filesystem::path wtAccessLogFilePath {ServiceProvider<IConfig>::get()->getPath("access-log-file", "/var/log/lms.access.log")};
      -	const std::filesystem::path wtResourcesPath {ServiceProvider<IConfig>::get()->getPath("wt-resources", "/usr/share/Wt/resources")};
      +	const std::filesystem::path wtResourcesPath {ServiceProvider<IConfig>::get()->getPath("wt-resources", "${wt-lms}/share/Wt/resources")};
       
       	args.push_back(execPath);
       	args.push_back("--config=" + wtConfigPath.string());
    '')
    (writeText "increase-artist-view-count.patch" ''
      diff --git a/src/lms/ui/explore/ReleasesView.cpp b/src/lms/ui/explore/ReleasesView.cpp
      index 55b2772..62525ef 100644
      --- a/src/lms/ui/explore/ReleasesView.cpp
      +++ b/src/lms/ui/explore/ReleasesView.cpp
      @@ -84,7 +84,7 @@ Releases::addSome()
       {
       	bool moreResults {};
       
      -	const auto releasesId {getReleases(_container->count(), 20, moreResults)};
      +	const auto releasesId {getReleases(_container->count(), 100, moreResults)};
       	for (const Database::IdType releaseId : releasesId )
       	{
       		auto transaction {LmsApp->getDbSession().createSharedTransaction()};
    '')
  ];

  meta = with stdenv.lib; {
    description = "Lightweight, self-hosted, music streaming server.";
    longDescription = ''
      LMS is a self-hosted music streaming software: access your music
      collection from anywhere using a web interface or the subsonic API!
      Written in C++, it has a low memory footprint and even comes with a
      recommendation engine.
    '';
    homepage = https://github.com/epoupon/lms;
    downloadPage = "https://github.com/epoupon/lms";
    maintainers = with maintainers; [ arthur ];
    license = licenses.gpl3;
    platforms = platforms.all;
  };
}
