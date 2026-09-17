/// Builds Xtream Codes stream URLs for live, VOD, and series content.
///
/// Format:
///   Live:  {baseUrl}/live/{user}/{pass}/{streamId}.m3u8
///   VOD:   {baseUrl}/movie/{user}/{pass}/{streamId}.mp4
///   Series: {baseUrl}/series/{user}/{pass}/{episodeId}.mp4
class StreamUrlBuilder {
  StreamUrlBuilder._();

  static String live({
    required String baseUrl,
    required String username,
    required String password,
    required String streamId,
  }) {
    return '$baseUrl/live/$username/$password/$streamId.m3u8';
  }

  static String vod({
    required String baseUrl,
    required String username,
    required String password,
    required String streamId,
    required String containerExtension,
  }) {
    return '$baseUrl/movie/$username/$password/$streamId.$containerExtension';
  }

  static String series({
    required String baseUrl,
    required String username,
    required String password,
    required String episodeId,
    required String containerExtension,
  }) {
    return '$baseUrl/series/$username/$password/$episodeId.$containerExtension';
  }
}
