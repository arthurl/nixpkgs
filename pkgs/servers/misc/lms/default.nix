{ stdenv
, lib
, fetchFromGitHub
, writeText
, cmake
, pkg-config
, gtest
, boost
, zlib
, libarchive
, ffmpeg_4
, stb
, libconfig
, taglib
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
  version = "3.54.0";

  src = fetchFromGitHub {
    owner = "epoupon";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-Ifib3t642eK04RqyZSx852z6o4Pm9ppYpCmKv+3S1EY=";
  };

  nativeBuildInputs = [ cmake pkg-config gtest ];
  buildInputs = [
    boost.dev zlib.dev libarchive.dev ffmpeg.dev stb libconfig taglib wt-lms
  ];
  cmakeFlags = [ "-DIMAGE_LIBRARY=STB" "-DCMAKE_BUILD_TYPE=Debug" ];

  patches = [
    (writeText "insert-dependency-paths.patch" ''
      diff --git a/src/libs/av/impl/Transcoder.cpp b/src/libs/av/impl/Transcoder.cpp
      index 760376ef..54d6b660 100644
      --- a/src/libs/av/impl/Transcoder.cpp
      +++ b/src/libs/av/impl/Transcoder.cpp
      @@ -57,7 +57,7 @@ namespace lms::av::transcoding
       
           void Transcoder::init()
           {
      -        ffmpegPath = core::Service<core::IConfig>::get()->getPath("ffmpeg-file", "/usr/bin/ffmpeg");
      +        ffmpegPath = core::Service<core::IConfig>::get()->getPath("ffmpeg-file", "${ffmpeg.bin}/bin/ffmpeg");
               if (!std::filesystem::exists(ffmpegPath))
                   throw Exception{ "File '" + ffmpegPath.string() + "' does not exist!" };
           }
      diff --git a/src/lms/main.cpp b/src/lms/main.cpp
      index 63cb1309..ab53eec3 100644
      --- a/src/lms/main.cpp
      +++ b/src/lms/main.cpp
      @@ -97,7 +97,7 @@ namespace lms
               const std::filesystem::path wtConfigPath{ core::Service<core::IConfig>::get()->getPath("working-dir") / "wt_config.xml" };
               const std::filesystem::path wtLogFilePath{ core::Service<core::IConfig>::get()->getPath("log-file", "/var/log/lms.log") };
               const std::filesystem::path wtAccessLogFilePath{ core::Service<core::IConfig>::get()->getPath("access-log-file", "/var/log/lms.access.log") };
      -        const std::filesystem::path wtResourcesPath{ core::Service<core::IConfig>::get()->getPath("wt-resources", "/usr/share/Wt/resources") };
      +        const std::filesystem::path wtResourcesPath{ core::Service<core::IConfig>::get()->getPath("wt-resources", "${wt-lms}/share/Wt/resources") };
       
               args.push_back(execPath);
               args.push_back("--config=" + wtConfigPath.string());
    '')
    (writeText "increase-album-view-count.patch" ''
      diff --git a/src/lms/ui/explore/ReleasesView.hpp b/src/lms/ui/explore/ReleasesView.hpp
      index e81dcc48..644e6aa8 100644
      --- a/src/lms/ui/explore/ReleasesView.hpp
      +++ b/src/lms/ui/explore/ReleasesView.hpp
      @@ -44,7 +44,7 @@ namespace lms::ui
               std::vector<db::ReleaseId> getAllReleases();
       
               static constexpr std::size_t _maxItemsPerLine{ 6 };
      -        static constexpr std::size_t _batchSize{ _maxItemsPerLine };
      +        static constexpr std::size_t _batchSize{ _maxItemsPerLine * 5 };
               static constexpr std::size_t _maxCount{ _maxItemsPerLine * 500 };
       
               PlayQueueController& _playQueueController;
    '')
  ];

  meta = with lib; {
    description = "Lightweight / low memory music streaming server";
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
