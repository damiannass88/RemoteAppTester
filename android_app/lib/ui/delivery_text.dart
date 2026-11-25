import '../delivery/delivery_service.dart';
import '../transfer/delta_downloader.dart';
import '../i18n.dart';

/// „2.4 MB/s”.
String speedLabel(int bytesPerSecond) => tr('{0} MB/s', [(bytesPerSecond / 1048576).toStringAsFixed(1)]);

/// Jednolinijkowy opis stanu dostawy (pasek, podgląd w projekcie, ekran builda).
String deliveryStatusText(DeliveryStatus status) => switch (status.stage) {
      DeliveryStage.downloading => status.message ??
          [
            tr('Pobieranie {0}', [transferLabel(status.bytes, status.totalBytes, fullSize: status.delivery.sizeBytes.toInt())]),
            if (status.bytesPerSecond > 0) speedLabel(status.bytesPerSecond),
          ].join(' · '),
      DeliveryStage.installing => status.message ?? tr('Instalowanie…'),
      DeliveryStage.waitingForUser => status.message ?? tr('Nowa wersja gotowa do instalacji.'),
      DeliveryStage.done => tr('Zainstalowano.'),
      DeliveryStage.failed => status.message ?? tr('Błąd instalacji.'),
      DeliveryStage.idle => '',
    };
