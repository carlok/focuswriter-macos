// Loads images through the bundle's own Qt frameworks and plugins, the way
// FocusWriter loads theme backgrounds (QImageReader). Built by smoke.sh and
// run from inside a copy of FocusWriter.app.
//
// Usage: imagecheck file...   exits 1 if a required format is missing or a
// file fails to load.
#include <QGuiApplication>
#include <QImageReader>
#include <cstdio>

int main(int argc, char** argv)
{
	QGuiApplication app(argc, argv);
	int failures = 0;

	const QList<QByteArray> formats = QImageReader::supportedImageFormats();
	for (const char* required : { "svg", "svgz", "jpeg", "png", "gif", "tiff", "webp", "bmp" }) {
		if (!formats.contains(required)) {
			std::printf("MISSING format %s\n", required);
			++failures;
		}
	}

	for (int i = 1; i < argc; ++i) {
		QImageReader reader(QString::fromLocal8Bit(argv[i]));
		const QImage image = reader.read();
		if (image.isNull()) {
			std::printf("FAIL %s: %s\n", argv[i], qPrintable(reader.errorString()));
			++failures;
		} else {
			std::printf("OK   %s (%dx%d, %s)\n", argv[i], image.width(), image.height(), reader.format().constData());
		}
	}

	return failures ? 1 : 0;
}
