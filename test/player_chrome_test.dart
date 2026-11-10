import 'package:flutter_test/flutter_test.dart';
import 'package:nova_iptv/player/player_chrome.dart';

void main() {
  testWidgets('Idle hides chrome and pointer movement restores it', (
    tester,
  ) async {
    final chrome = PlayerChrome()..activity();
    addTearDown(chrome.dispose);
    await tester.pump(const Duration(seconds: 2));
    expect(chrome.visible, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(chrome.visible, isFalse);
    chrome.pointerEnter();
    expect(chrome.visible, isTrue);
    chrome.pointerExit();
    expect(chrome.visible, isFalse);
  });

  testWidgets('Blur hides chrome until activity returns to the player', (
    tester,
  ) async {
    final chrome = PlayerChrome()..activity();
    addTearDown(chrome.dispose);
    chrome.focusLost();
    chrome.activity();
    expect(chrome.visible, isFalse);
    chrome.focusGained();
    expect(chrome.visible, isFalse);
    chrome.pointerEnter();
    expect(chrome.visible, isTrue);
    chrome.pointerExit();
  });

  testWidgets('Menus stay visible while being used and release idle timer', (
    tester,
  ) async {
    final chrome = PlayerChrome()..menuOpened();
    addTearDown(chrome.dispose);
    chrome.pointerExit();
    await tester.pump(const Duration(seconds: 10));
    expect(chrome.visible, isTrue);
    chrome.menuClosed();
    expect(chrome.visible, isFalse);
    chrome.pointerEnter();
    chrome.menuOpened();
    chrome.dismissMenus();
    await tester.pump(const Duration(seconds: 3));
    expect(chrome.visible, isFalse);
  });
}
