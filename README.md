# ChromaCam

PB（#F40671） / BB（#0069FC） / YB（#FDB200）の背景を自動判別して透過し、カメラ映像に重ねて撮影する Flutter アプリです。

非公式の個人制作です。バンダイナムコエンターテインメント および Cygames とは無関係です。
ゲーム画像は配布しません。自分で撮ったスクリーンショットだけを端末内で処理します。

## できること

- 画像の複数選択・あとからの追加
- 背景色の自動判別とクロマキー透過
- 透過素材をカメラに重ねて撮影
- 複数レイヤーの移動・拡大縮小・不透明度・並べ替え
- 縦 3:4 / 横 4:3 のプレビューと保存
- カメラ倍率
- 配置リセット
- アルバム「ChromaCam」へ PNG 保存

## 使い方

1. フォトスタジオなどで PB / BB / YB 背景の画像を用意する
2. アプリで「ファイルを選ぶ」
3. 「カメラで撮る」
4. 位置と大きさを合わせて撮影する

## 動作環境

- Android 8 以降を目安（実機確認済み）
- カメラ権限、画像保存権限が必要
- 現時点の配布は Android（APK）が中心
- iOS はソースからビルド可能だが、App Store 配布は未対応

## ビルド

```bash
flutter pub get
flutter run
```

Android APK:

```bash
flutter build apk --release
```

成果物は `build/app/outputs/flutter-apk/app-release.apk` です。

iOS（macOS + Xcode が必要）:

```bash
flutter build ios --release
```

その後 Xcode で署名して実機またはアーカイブします。

## 権限

Android (`android/app/src/main/AndroidManifest.xml`)

- `CAMERA`
- `INTERNET`
- 保存は `gal` 経由（端末の写真権限ダイアログが出る）

## 注意

- いわゆる野良 APK です。インストール時に「提供元不明のアプリ」を許可する必要があります

## ライセンス

ソースコードは作者の判断で公開しています。
ゲーム内のキャラクター・画像の権利は各権利者に帰属します。
