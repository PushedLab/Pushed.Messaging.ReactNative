import notifee from '@notifee/react-native';

let channelId: string = '';

export async function initNotifications() {
  // Request permissions (required for iOS)
  await notifee.requestPermission();

  // Create a channel (required for Android)
  channelId = await notifee.createChannel({
    id: 'default',
    name: 'Default Channel',
  });
}

export async function displayNotification(title: string, body: string) {
  await notifee.displayNotification({
    title: title,
    body: body,
    android: {
      channelId,
    },
  });
}
