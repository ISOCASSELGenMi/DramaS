// 本檔案定義 MyAnimeList (MAL) 的設置路由模組，
// 用於將對應的 MAL 設置頁面註冊到 Flutter Modular 路由系統中。
import 'package:flutter_modular/flutter_modular.dart';
import 'mal_setting.dart';

class MalModule extends Module {
  @override
  void routes(r) {
    r.child("/", child: (_) => const MalEditorPage());
  }
}
