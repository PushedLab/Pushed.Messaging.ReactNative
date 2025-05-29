import { useState, useEffect } from 'react';
import {
  StyleSheet,
  View,
  TextInput,
  Text,
} from 'react-native';
import {
  startService,
} from '@PushedLab/pushed-react-native';
import { initNotifications } from './Notifee';

export default function App() {
  const [token, setToken] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    initNotifications();
    
    // Автоматически запускаем сервис при загрузке приложения
    console.log('Auto-starting Pushed Service');
    startService('PushedService').then((newToken: string) => {
      console.log(`Service has started: ${newToken}`);
      setToken(newToken);
      setIsLoading(false);
    }).catch((error: any) => {
      console.error('Failed to start service:', error);
      setIsLoading(false);
    });

    // Убираем обработку push событий - все трекинг происходит нативно
    // const eventEmitter = new NativeEventEmitter(
    //   NativeModules.PushedReactNative
    // );
    // const eventListener = eventEmitter.addListener(
    //   PushedEventTypes.PUSH_RECEIVED,
    //   (push: Push) => {
    //     console.log(push);
    //     displayNotification(
    //       push?.title ?? '',
    //       push?.body ?? JSON.stringify(push)
    //     );
    //   }
    // );

    // return () => {
    //   eventListener.remove();
    // };
  }, []);

  return (
    <View style={styles.container}>
      {isLoading ? (
        <Text style={styles.loadingLabel}>Initializing Pushed Service...</Text>
      ) : token ? (
        <>
          <Text style={styles.label}>Pushed Token:</Text>
          <TextInput
            style={styles.textInput}
            value={token}
            editable={false}
            selectTextOnFocus={true}
            multiline={true}
          />
          <Text style={styles.statusLabel}>Service is running</Text>
        </>
      ) : (
        <Text style={styles.errorLabel}>Failed to initialize service</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    gap: 2,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  label: {
    marginBottom: 10,
    fontSize: 16,
    fontWeight: 'bold',
  },
  textInput: {
    minHeight: 80,
    borderColor: 'gray',
    borderWidth: 1,
    marginBottom: 20,
    paddingHorizontal: 10,
    paddingVertical: 10,
    width: '90%',
    textAlign: 'center',
    backgroundColor: '#f5f5f5',
  },
  loadingLabel: {
    fontSize: 16,
    color: 'blue',
  },
  statusLabel: {
    fontSize: 14,
    color: 'green',
    fontWeight: 'bold',
  },
  errorLabel: {
    fontSize: 16,
    color: 'red',
  },
});
