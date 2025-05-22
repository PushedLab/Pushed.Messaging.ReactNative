import { useState, useEffect } from 'react';
import {
  StyleSheet,
  View,
  Button,
  TextInput,
  Text,
  NativeEventEmitter,
  NativeModules,
} from 'react-native';
import {
  startService,
  stopService,
  PushedEventTypes,
  Push,
} from '@PushedLab/pushed-react-native';
import { displayNotification, initNotifications } from './Notifee';

export default function App() {
  const [serviceStarted, setServiceStarted] = useState(false);
  const [token, setToken] = useState('');

  const handleStart = () => {
    console.log('Starting Pushed Service');
    startService('PushedService').then((newToken) => {
      console.log(`Service has started: ${newToken}`);
      setToken(newToken);
      setServiceStarted(true);
    });
  };

  const handleStop = () => {
    stopService().then((message) => {
      console.log(message);
      setToken('');
      setServiceStarted(false);
    });
  };

  useEffect(() => {
    initNotifications();
    const eventEmitter = new NativeEventEmitter(
      NativeModules.PushedReactNative
    );
    const eventListener = eventEmitter.addListener(
      PushedEventTypes.PUSH_RECEIVED,
      (push: Push) => {
        console.log(push);
        displayNotification(
          push?.title ?? '',
          push?.body ?? JSON.stringify(push)
        );
      }
    );

    // Removes the listener once unmounted
    return () => {
      eventListener.remove();
    };
  }, []);

  return (
    <View style={styles.container}>
      {serviceStarted ? (
        <>
          <Text style={styles.label}>Token:</Text>
          <TextInput
            style={styles.textInput}
            value={token}
            editable={false}
            selectTextOnFocus={true}
          />
        </>
      ) : (
        <Text style={styles.notListeningLabel}>Service is not listening</Text>
      )}
      <View style={styles.buttonRow}>
        <Button title="Start" onPress={handleStart} disabled={serviceStarted} />
        <Button title="Stop" onPress={handleStop} disabled={!serviceStarted} />
      </View>
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
  },
  textInput: {
    height: 40,
    borderColor: 'gray',
    borderWidth: 1,
    marginBottom: 20,
    paddingHorizontal: 10,
    width: '90%',
    textAlign: 'center',
  },
  notListeningLabel: {
    marginBottom: 20,
    fontSize: 16,
    color: 'red',
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 16,
    width: '80%',
  },
  button: {
    flex: 1,
    marginHorizontal: 5,
  },
});
