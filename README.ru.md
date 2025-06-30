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

#### Настройка Notification Service Extension (iOS)

Для автоматического подтверждения получения сообщений (*endpoint* `/confirm`) рекомендуется добавить **Notification Service Extension** в ваше iOS-приложение. Расширение перехватывает входящий push до его показа системой и отправляет подтверждение от имени пользователя.

Шаги настройки:

1. Откройте проект в **Xcode** и выберите `File ▸ New ▸ Target…`, затем в списке **iOS** выберите **Notification Service Extension**.
2. Задайте имя, например `AppNotiService`, и завершите мастер. Xcode создаст файл `NotificationService.swift`.
3. Замените содержимое созданного файла на пример из `example/ios/AppNotiService/NotificationService.swift` или адаптируйте под свои нужды.
4. В **Signing & Capabilities** включите **Keychain Sharing** для *основного приложения* и *расширения* и убедитесь, что в обоих целей указана одна и та же access-group. Это даст расширению доступ к `clientToken`, сохранённому библиотекой в Keychain.
5. Убедитесь, что расширение подписывается той же командой разработчика (**Team**) и имеет bundle identifier в том же пространстве, например `com.yourapp.notification-service`.
6. Соберите приложение. При получении push-уведомления система запустит расширение, код библиотеки отправит запрос подтверждения, после чего уведомление будет показано пользователю.

> Важно: payload пуша должен содержать поле `messageId`. Без него подтверждение отправлено не будет.

### Описание методов и типов библиотеки pushed-react-native
#### `startService(serviceName: string): Promise<string>`
Эта функция запускает службу push-уведомлений.
- **Параметры:**
 - `serviceName`: `строка`, представляющая имя запускаемой службы.
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
