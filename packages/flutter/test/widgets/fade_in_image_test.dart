// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../image_data.dart';
import '../painting/image_test_utils.dart';

const Duration animationDuration = Duration(milliseconds: 50);

class FadeInImageParts {
  const FadeInImageParts(this.fadeInImageElement, this.placeholder, this.target)
      : assert(fadeInImageElement != null),
        assert(target != null);

  final ComponentElement fadeInImageElement;
  final FadeInImageElements? placeholder;
  final FadeInImageElements target;

  State? get state {
    StatefulElement? animatedFadeOutFadeInElement;
    fadeInImageElement.visitChildren((Element child) {
      expect(animatedFadeOutFadeInElement, isNull);
      animatedFadeOutFadeInElement = child as StatefulElement;
    });
    expect(animatedFadeOutFadeInElement, isNotNull);
    return animatedFadeOutFadeInElement!.state;
  }

  Element? get semanticsElement {
    Element? result;
    fadeInImageElement.visitChildren((Element child) {
      if (child.widget is Semantics)
        result = child;
    });
    return result;
  }
}

class FadeInImageElements {
  const FadeInImageElements(this.rawImageElement);

  final Element rawImageElement;

  RawImage get rawImage => rawImageElement.widget as RawImage;
  double get opacity => rawImage.opacity?.value ?? 1.0;
}

class LoadTestImageProvider extends ImageProvider<Object> {
  LoadTestImageProvider(this.provider);

  final ImageProvider provider;

  ImageStreamCompleter testLoad(Object key, DecoderCallback decode) {
    return provider.load(key, decode);
  }

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) {
    throw UnimplementedError();
  }

  @override
  ImageStreamCompleter load(Object key, DecoderCallback decode) {
    throw UnimplementedError();
  }
}

FadeInImageParts findFadeInImage(WidgetTester tester) {
  final List<FadeInImageElements> elements = <FadeInImageElements>[];
  final Iterable<Element> rawImageElements = tester.elementList(find.byType(RawImage));
  ComponentElement? fadeInImageElement;
  for (final Element rawImageElement in rawImageElements) {
    rawImageElement.visitAncestorElements((Element ancestor) {
      if (ancestor.widget is FadeInImage) {
        if (fadeInImageElement == null) {
          fadeInImageElement = ancestor as ComponentElement;
        } else {
          expect(fadeInImageElement, same(ancestor));
        }
        return false;
      }
      return true;
    });
    expect(fadeInImageElement, isNotNull);
    elements.add(FadeInImageElements(rawImageElement));
  }
  if (elements.length == 2) {
    return FadeInImageParts(fadeInImageElement!, elements.last, elements.first);
  } else {
    expect(elements, hasLength(1));
    return FadeInImageParts(fadeInImageElement!, null, elements.first);
  }
}

Future<void> main() async {
  // These must run outside test zone to complete
  final ui.Image targetImage = await createTestImage();
  final ui.Image placeholderImage = await createTestImage();
  final ui.Image replacementImage = await createTestImage();

  group('FadeInImage', () {
    testWidgets('animates an uncached image', (WidgetTester tester) async {
      final TestImageProvider placeholderProvider = TestImageProvider(placeholderImage);
      final TestImageProvider imageProvider = TestImageProvider(targetImage);

      await tester.pumpWidget(FadeInImage(
        placeholder: placeholderProvider,
        image: imageProvider,
        fadeOutDuration: animationDuration,
        fadeInDuration: animationDuration,
        fadeOutCurve: Curves.linear,
        fadeInCurve: Curves.linear,
        excludeFromSemantics: true,
      ));

      expect(findFadeInImage(tester).placeholder!.rawImage.image, null);
      expect(findFadeInImage(tester).target.rawImage.image, null);

      placeholderProvider.complete();
      await tester.pump();
      expect(findFadeInImage(tester).placeholder!.rawImage.image!.isCloneOf(placeholderImage), true);
      expect(findFadeInImage(tester).target.rawImage.image, null);

      imageProvider.complete();
      await tester.pump();
      for (int i = 0; i < 5; i += 1) {
        final FadeInImageParts parts = findFadeInImage(tester);
        expect(parts.placeholder!.rawImage.image!.isCloneOf(placeholderImage), true);
        expect(parts.target.rawImage.image!.isCloneOf(targetImage), true);
        expect(parts.placeholder!.opacity, moreOrLessEquals(1 - i / 5));
        expect(parts.target.opacity, 0);
        await tester.pump(const Duration(milliseconds: 10));
      }

      for (int i = 0; i < 5; i += 1) {
        final FadeInImageParts parts = findFadeInImage(tester);
        expect(parts.placeholder!.rawImage.image!.isCloneOf(placeholderImage), true);
        expect(parts.target.rawImage.image!.isCloneOf(targetImage), true);
        expect(parts.placeholder!.opacity, 0);
        expect(parts.target.opacity, moreOrLessEquals(i / 5));
        await tester.pump(const Duration(milliseconds: 10));
      }

      await tester.pumpWidget(FadeInImage(
        placeholder: placeholderProvider,
        image: imageProvider,
      ));
      expect(findFadeInImage(tester).target.rawImage.image!.isCloneOf(targetImage), true);
      expect(findFadeInImage(tester).target.opacity, 1);
    });

    testWidgets('shows a cached image immediately when skipFadeOnSynchronousLoad=true', (WidgetTester tester) async {
      final TestImageProvider placeholderProvider = TestImageProvider(placeholderImage);
      final TestImageProvider imageProvider = TestImageProvider(targetImage);
      imageProvider.resolve(ImageConfiguration.empty);
      imageProvider.complete();

      await tester.pumpWidget(FadeInImage(
        placeholder: placeholderProvider,
        image: imageProvider,
      ));

      expect(findFadeInImage(tester).target.rawImage.image!.isCloneOf(targetImage), true);
      expect(findFadeInImage(tester).placeholder, isNull);
      expect(findFadeInImage(tester).target.opacity, 1);
    });

    testWidgets('handles updating the placeholder image', (WidgetTester tester) async {
      final TestImageProvider placeholderProvider = TestImageProvider(placeholderImage);
      final TestImageProvider secondPlaceholderProvider = TestImageProvider(replacementImage);
      final TestImageProvider imageProvider = TestImageProvider(targetImage);

      await tester.pumpWidget(FadeInImage(
        placeholder: placeholderProvider,
        image: imageProvider,
        fadeOutDuration: animationDuration,
        fadeInDuration: animationDuration,
        excludeFromSemantics: true,
      ));

      final State? state = findFadeInImage(tester).state;
      placeholderProvider.complete();
      await tester.pump();
      expect(findFadeInImage(tester).placeholder!.rawImage.image!.isCloneOf(placeholderImage), true);

      await tester.pumpWidget(FadeInImage(
        placeholder: secondPlaceholderProvider,
        image: imageProvider,
        fadeOutDuration: animationDuration,
        fadeInDuration: animationDuration,
        excludeFromSemantics: true,
      ));

      secondPlaceholderProvider.complete();
      await tester.pump();
      expect(findFadeInImage(tester).placeholder!.rawImage.image!.isCloneOf(replacementImage), true);
      expect(findFadeInImage(tester).state, same(state));
    });

    testWidgets('does not keep the placeholder in the tree if it is invisible', (WidgetTester tester) async {
      final TestImageProvider placeholderProvider = TestImageProvider(placeholderImage);
      final TestImageProvider imageProvider = TestImageProvider(targetImage);

      await tester.pumpWidget(FadeInImage(
        placeholder: placeholderProvider,
        image: imageProvider,
        fadeOutDuration: animationDuration,
        fadeInDuration: animationDuration,
        excludeFromSemantics: true,
      ));

      placeholderProvider.complete();
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNWidgets(2));

      imageProvider.complete();
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('re-fades in the image when the target image is updated', (WidgetTester tester) async {
      final TestImageProvider placeholderProvider = TestImageProvider(placeholderImage);
      final TestImageProvider imageProvider = TestImageProvider(targetImage);
      final TestImageProvider secondImageProvider = TestImageProvider(replacementImage);

      await tester.pumpWidget(FadeInImage(
        placeholder: placeholderProvider,
        image: imageProvider,
        fadeOutDuration: animationDuration,
        fadeInDuration: animationDuration,
        excludeFromSemantics: true,
      ));

      final State? state = findFadeInImage(tester).state;
      placeholderProvider.complete();
      imageProvider.complete();
      await tester.pump();
      await tester.pump(animationDuration * 2);

      await tester.pumpWidget(FadeInImage(
        placeholder: placeholderProvider,
        image: secondImageProvider,
        fadeOutDuration: animationDuration,
        fadeInDuration: animationDuration,
        excludeFromSemantics: true,
      ));

      secondImageProvider.complete();
      await tester.pump();

      expect(findFadeInImage(tester).target.rawImage.image!.isCloneOf(replacementImage), true);
      expect(findFadeInImage(tester).state, same(state));
      expect(findFadeInImage(tester).placeholder!.opacity, moreOrLessEquals(1));
      expect(findFadeInImage(tester).target.opacity, moreOrLessEquals(0));
      await tester.pump(animationDuration);
      expect(findFadeInImage(tester).placeholder!.opacity, moreOrLessEquals(0));
      expect(findFadeInImage(tester).target.opacity, moreOrLessEquals(0));
      await tester.pump(animationDuration);
      expect(findFadeInImage(tester).placeholder!.opacity, moreOrLessEquals(0));
      expect(findFadeInImage(tester).target.opacity, moreOrLessEquals(1));
    });

    testWidgets("doesn't interrupt in-progress animation when animation values are updated", (WidgetTester tester) async {
      final TestImageProvider placeholderProvider = TestImageProvider(placeholderImage);
      final TestImageProvider imageProvider = TestImageProvider(targetImage);

      await tester.pumpWidget(FadeInImage(
        placeholder: placeholderProvider,
        image: imageProvider,
        fadeOutDuration: animationDuration,
        fadeInDuration: animationDuration,
        excludeFromSemantics: true,
      ));

      final State? state = findFadeInImage(tester).state;
      placeholderProvider.complete();
      imageProvider.complete();
      await tester.pump();
      await tester.pump(animationDuration);

      await tester.pumpWidget(FadeInImage(
        placeholder: placeholderProvider,
        image: imageProvider,
        fadeOutDuration: animationDuration * 2,
        fadeInDuration: animationDuration * 2,
        excludeFromSemantics: true,
      ));

      expect(findFadeInImage(tester).state, same(state));
      expect(findFadeInImage(tester).placeholder!.opacity, moreOrLessEquals(0));
      expect(findFadeInImage(tester).target.opacity, moreOrLessEquals(0));
      await tester.pump(animationDuration);
      expect(findFadeInImage(tester).placeholder!.opacity, moreOrLessEquals(0));
      expect(findFadeInImage(tester).target.opacity, moreOrLessEquals(1));
    });

    group('ImageProvider', () {

      testWidgets('memory placeholder cacheWidth and cacheHeight is passed through', (WidgetTester tester) async {
        final Uint8List testBytes = Uint8List.fromList(kTransparentImage);
        final FadeInImage image = FadeInImage.memoryNetwork(
          placeholder: testBytes,
          image: 'test.com',
          placeholderCacheWidth: 20,
          placeholderCacheHeight: 30,
          imageCacheWidth: 40,
          imageCacheHeight: 50,
        );

        bool called = false;
        Future<ui.Codec> decode(Uint8List bytes, {int? cacheWidth, int? cacheHeight, bool allowUpscaling = false}) {
          expect(cacheWidth, 20);
          expect(cacheHeight, 30);
          expect(allowUpscaling, false);
          called = true;
          return PaintingBinding.instance!.instantiateImageCodec(bytes, cacheWidth: cacheWidth, cacheHeight: cacheHeight, allowUpscaling: allowUpscaling);
        }
        final ImageProvider resizeImage = image.placeholder;
        expect(image.placeholder, isA<ResizeImage>());
        expect(called, false);
        final LoadTestImageProvider testProvider = LoadTestImageProvider(image.placeholder);
        testProvider.testLoad(await resizeImage.obtainKey(ImageConfiguration.empty), decode);
        expect(called, true);
      });

      testWidgets('do not resize when null cache dimensions', (WidgetTester tester) async {
        final Uint8List testBytes = Uint8List.fromList(kTransparentImage);
        final FadeInImage image = FadeInImage.memoryNetwork(
          placeholder: testBytes,
          image: 'test.com',
        );

        bool called = false;
        Future<ui.Codec> decode(Uint8List bytes, {int? cacheWidth, int? cacheHeight, bool allowUpscaling = false}) {
          expect(cacheWidth, null);
          expect(cacheHeight, null);
          expect(allowUpscaling, false);
          called = true;
          return PaintingBinding.instance!.instantiateImageCodec(bytes, cacheWidth: cacheWidth, cacheHeight: cacheHeight);
        }
        // image.placeholder should be an instance of MemoryImage instead of ResizeImage
        final ImageProvider memoryImage = image.placeholder;
        expect(image.placeholder, isA<MemoryImage>());
        expect(called, false);
        final LoadTestImageProvider testProvider = LoadTestImageProvider(image.placeholder);
        testProvider.testLoad(await memoryImage.obtainKey(ImageConfiguration.empty), decode);
        expect(called, true);
      });
    });

    group('semantics', () {
      testWidgets('only one Semantics node appears within FadeInImage', (WidgetTester tester) async {
        final TestImageProvider placeholderProvider = TestImageProvider(placeholderImage);
        final TestImageProvider imageProvider = TestImageProvider(targetImage);

        await tester.pumpWidget(FadeInImage(
          placeholder: placeholderProvider,
          image: imageProvider,
        ));

        expect(find.byType(Semantics), findsOneWidget);
      });

      testWidgets('is excluded if excludeFromSemantics is true', (WidgetTester tester) async {
        final TestImageProvider placeholderProvider = TestImageProvider(placeholderImage);
        final TestImageProvider imageProvider = TestImageProvider(targetImage);

        await tester.pumpWidget(FadeInImage(
          placeholder: placeholderProvider,
          image: imageProvider,
          excludeFromSemantics: true,
        ));

        expect(find.byType(Semantics), findsNothing);
      });

      group('label', () {
        const String imageSemanticText = 'Test image semantic label';

        testWidgets('defaults to image label if placeholder label is unspecified', (WidgetTester tester) async {
          Semantics semanticsWidget() => tester.widget(find.byType(Semantics));

          final TestImageProvider placeholderProvider = TestImageProvider(placeholderImage);
          final TestImageProvider imageProvider = TestImageProvider(targetImage);

          await tester.pumpWidget(Directionality(
            textDirection: TextDirection.ltr,
            child: FadeInImage(
              placeholder: placeholderProvider,
              image: imageProvider,
              fadeOutDuration: animationDuration,
              fadeInDuration: animationDuration,
              imageSemanticLabel: imageSemanticText,
            ),
          ));

          placeholderProvider.complete();
          await tester.pump();
          expect(semanticsWidget().properties.label, imageSemanticText);

          imageProvider.complete();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 51));
          expect(semanticsWidget().properties.label, imageSemanticText);
        });

        testWidgets('is empty without any specified semantics labels', (WidgetTester tester) async {
          Semantics semanticsWidget() => tester.widget(find.byType(Semantics));

          final TestImageProvider placeholderProvider = TestImageProvider(placeholderImage);
          final TestImageProvider imageProvider = TestImageProvider(targetImage);

          await tester.pumpWidget(FadeInImage(
              placeholder: placeholderProvider,
              image: imageProvider,
              fadeOutDuration: animationDuration,
              fadeInDuration: animationDuration,
          ));

          placeholderProvider.complete();
          await tester.pump();
          expect(semanticsWidget().properties.label, isEmpty);

          imageProvider.complete();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 51));
          expect(semanticsWidget().properties.label, isEmpty);
        });
      });
    });
  });
}
