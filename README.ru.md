## Pushed React Native - интеграция Pushed.ru и React Native
### Обзор
Этот пакет позволяет интегрировать службу push-уведомлений Pushed.ru в ваше приложение React Native. 
### Примеры использования
Вы можете посмотреть пример использования запустив приложение example из этого репозитория.

### Инструкция по использованию
Выполните следующие шаги, чтобы использовать пакет pushed-react-native в своем приложении React Native.
#### 1. Установите библиотеку
Запустите следующую команду, чтобы установить библиотеку:
```bash
npm install pushed-react-native --registry=https://son.multifactor.dev:5443/repository/pushed-npm
```

#### 2. Импортируйте необходимые методы и типы
Импортируйте необходимые методы и типы из библиотеки:
```javascript
import {
  startService,
  stopService,
  PushedEventTypes,
  Push,
} from 'pushed-react-native';
```

#### 3. Подпишитесь на событие `PushedEventTypes.PUSH_RECEIVED`
Подпишитесь на событие PUSH_RECEIVED для обработки входящих push-уведомлений:
```javascript
import React, { useEffect } from 'react';
import { NativeEventEmitter, NativeModules } from 'react-native';
import { displayNotification } from './Notifee';

useEffect(() => {
  const eventEmitter = new NativeEventEmitter(NativeModules.PushedReactNative);
  const eventListener = eventEmitter.addListener(
    PushedEventTypes.PUSH_RECEIVED,
    (push: Push) => {
      console.log(push);
      displayNotification(push.title, push.body);
    }
  );

  // Remove the listener when the component unmounts
  return () => {
    eventListener.remove();
  };
}, []);
```

#### 4. Запустите сервис приема сообщений
Используйте функцию `startService` для запуска службы, отвечающей за прием сообщений:
```javascript
const handleStart = () => {
  console.log('Starting Pushed Service');
  startService('PushedService').then((newToken) => {
    console.log(`Service has started: ${newToken}`);
  });
};
```

#### 5. Остановите сервис приема сообщений
Используйте функцию `stopService` для остановки службы, отвечающей за прием сообщений:
```Javascript
const handleStop = () => {
 stopService().then((m) => {
 console.log(m);
 });
};
```

#### Особенности работы в iOS

1. Сообщения доставляются посредством службы apns и обрабатываются самим устройством в фоновом режиме. startService можно вызвать только один раз,
   чтобы зарегистрировать клиентский токен.
2. Необходимо настроить ваше приложение для работы с apns в панели управления Pushed (см. статью)[https://pushed.ru/docs/apns/]
3. Убедитесь, что приложение имеет разрешения Push Notifications и Background Modes -> Remote Notifications

#### iOS: Notification Service Extension (подтверждение + SHOW)

Рекомендуем добавить Extension, чтобы подтверждать доставку APNs до показа и исключить дубли с WebSocket.

1) Podfile
Добавьте отдельный под только для Extension:
```ruby
target 'AppNotiService' do
  pod 'pushed-react-native-extension', :path => '../node_modules/@PushedLab/pushed-react-native'
end
```

2) Импорт и код в Extension (полный пример)
Ниже приведена полная реализация `NotificationService.swift`:
```swift
import UserNotifications
import Foundation
import pushed_react_native_extension

@objc(NotificationService)
class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        NSLog("[Extension] didReceiveNotificationRequest called with userInfo: \(request.content.userInfo)")

        // Обрабатываем messageId через helper: сохраняет в App Group и подтверждает доставку
        if let messageId = request.content.userInfo["messageId"] as? String {
            NSLog("[Extension] Found messageId: \(messageId), delegating to PushedIosLib")
            PushedExtensionHelper.processMessage(messageId)
        } else {
            NSLog("[Extension] No messageId found in notification")
        }

        // Всегда возвращаем контент системе
        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
```

3) App Group (обязательно)
- Включите App Group для приложения и Extension с одинаковым идентификатором, напр. `group.ru.pushed.messaging`.
- Extension пишет обработанные `messageId` в App Group; при старте приложение сливает их в свой кэш, чтобы не показывать дубль из WebSocket после холодного старта.

4) Keychain Sharing
- Включите Keychain Sharing для обоих таргетов и укажите одну и ту же access‑group — Extension должен читать `clientToken`, сохранённый приложением.

5) Примечания
- В payload должен быть `messageId`.
- Либа автоматически мерджит доставленные уведомления и App Group при старте.

### Описание методов и типов библиотеки pushed-react-native
#### `startService(serviceName: string, applicationId?: string): Promise<string>`
Эта функция запускает службу push-уведомлений.
- **Параметры:**
 - `serviceName`: `строка`, представляющая имя запускаемой службы.
 - `applicationId` *(необязательный)*: `строка` — ваш идентификатор приложения `applicationId` в Pushed. Если параметр указан, токен клиента будет сразу инициализирован для этого приложения.  
   Также можно вызвать `setApplicationId('YOUR_APP_ID')` до запуска `startService`.
- **Возвращаемое значение:**
 - `Promise<string>`, который резолвится токеном устройства, который понадобится при отправке пуша. См. пример.
#### `stopService(): Promise<string>`
Эта функция останавливает службу push-уведомлений.
- **Возвращаемое значение:**
 - `Promise<string>`, который резолвится сообщением, указывающим, что служба остановлена.
#### `PushedEventTypes`
Это перечисление содержит типы событий, с которыми работает система Pushed.ru
- **Перечисляемые значения:**
 - `PUSH_RECEIVED`: представляет тип события при получении push-уведомления.
#### `Push`
Это класс, представляющий push-уведомление, он является оберткой произвольного словаря key-value
 - **Constructor:**
  - `constructor(data: { [key: string]: string })`
    - Cоздает новый экземпляр Push, используя предоставленные данные.
