// lib/mobile/duel/invite.dart
// 카카오톡 친구 초대: 카카오 SDK 메시지 카드(버튼 → 앱 열림 + 초대 코드). 받는 쪽은 앱 열리면 pendingInvite로.
// 카카오 앱 키가 없거나 카톡이 없으면 시스템 공유 시트로 코드 + 스토어 링크를 보낸다.
import 'package:flutter/widgets.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:share_plus/share_plus.dart';

/// developers.kakao.com 앱 → 앱 키 → 네이티브 앱 키. iOS Info.plist·Android Manifest의 kakao<키> 스킴과 같아야 한다.
const kakaoNativeKey = '6a8ada13600885965d103fff15c630f2';

final storeUrl = Uri.parse('https://apps.apple.com/kr/app/id6821653231');
final _siteUrl = Uri.parse('https://olv.is/fokko'); // 카카오 앱 플랫폼에 등록한 도메인

/// 카톡 카드 버튼이나 코드로 들어온 초대 (셸이 듣고 대결 화면을 연다)
final pendingInvite = ValueNotifier<String?>(null);

Future<void> initKakao() async {
  if (kakaoNativeKey.isEmpty) return;
  await KakaoSdk.init(nativeAppKey: kakaoNativeKey);
  receiveKakaoScheme((uri) {
    final code = uri.queryParameters['invite'];
    if (code != null && code.isNotEmpty) pendingInvite.value = code;
  });
}

String inviteText(String nickname, String code) =>
    '$nickname님이 Fokko 집중 대결을 신청했어요!\n'
    '이번 주 누가 더 오래 집중하는지 1:1로 겨뤄요.\n\n'
    '초대 코드: $code';

/// 카톡 카드로 보내고, 못 하면 공유 시트. [origin]은 iPad 공유 팝오버 위치.
Future<void> sendInvite(String nickname, String code, {Rect? origin}) async {
  if (kakaoNativeKey.isNotEmpty) {
    try {
      if (await ShareClient.instance.isKakaoTalkSharingAvailable()) {
        final params = {'invite': code};
        await ShareClient.instance.shareDefault(
          template: TextTemplate(
            text: inviteText(nickname, code),
            link: Link(webUrl: _siteUrl, mobileWebUrl: _siteUrl),
            buttons: [
              Button(
                title: '대결 수락하기',
                link: Link(
                    androidExecutionParams: params, iosExecutionParams: params),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('kakao share: $e'); // 공유 시트로
    }
  }
  await SharePlus.instance.share(ShareParams(
    text: '${inviteText(nickname, code)}\n'
        '앱을 열고 기록 → 1:1 대결 → 코드 입력\n$storeUrl',
    sharePositionOrigin: origin,
  ));
}
