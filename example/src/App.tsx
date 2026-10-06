import { useState, useEffect } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TouchableOpacity,
  Image,
  Clipboard,
  Alert,
  StatusBar,
  NativeEventEmitter,
  NativeModules,
  Platform,
} from 'react-native';
import {
  startService,
  PushedEventTypes,
  setUseNativeNotifications,
} from '@PushedLab/pushed-react-native';
import { initNotifications, displayNotification } from './Notifee';

export default function App() {
  const [token, setToken] = useState('');
  const [isLoading, setIsLoading] = useState(true);
  const [serviceActive, setServiceActive] = useState(false);

  useEffect(() => {
    initNotifications();

    // На Android уведомление рисует нативный SDK — так работает переход по
    // pushedNotification.url при нажатии. Должно стоять ДО startService.
    setUseNativeNotifications(Platform.OS === 'android');

    // Автоматически запускаем сервис при загрузке приложения
    console.log('Auto-starting Pushed Service');
    startService('', '').then((newToken: string) => {
      console.log(`Service has started: ${newToken}`);
      setToken(newToken);
      setServiceActive(true);
      setIsLoading(false);
    }).catch((error: any) => {
      console.error('Failed to start service:', error);
      setIsLoading(false);
    });

    const eventEmitter = new NativeEventEmitter(
      NativeModules.PushedReactNative
    );

    function extractTitleBody(input: any): { title: string; body: string } {
      try {
        // Native emits { message: string }, but allow direct object/string too
        const raw = typeof input === 'string' ? input : (input?.message ?? input);
        const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;

        // 1) pushedNotification format
        const pn = parsed?.pushedNotification;
        if (pn && (pn.Title || pn.Body)) {
          return {
            title: pn.Title ?? '',
            body: pn.Body ?? '',
          };
        }

        // 2) APNs aps.alert format
        const aps = parsed?.aps;
        if (aps?.alert) {
          if (typeof aps.alert === 'string') {
            return { title: '', body: aps.alert };
          }
          return {
            title: aps.alert.title ?? '',
            body: aps.alert.body ?? '',
          };
        }

        // 3) Flat title/body
        if (parsed?.title || parsed?.body) {
          return { title: parsed.title ?? '', body: parsed.body ?? '' };
        }

        // 4) Fallback to data/message
        const bodyStr =
          typeof parsed?.data === 'string'
            ? parsed.data
            : parsed?.message ?? JSON.stringify(parsed ?? input);
        return { title: 'Новое сообщение', body: bodyStr };
      } catch (e) {
        // Non‑JSON payload – show as text
        const text = typeof input === 'string' ? input : JSON.stringify(input);
        return { title: 'Новое сообщение', body: text };
      }
    }

    const eventListener = eventEmitter.addListener(
      PushedEventTypes.PUSH_RECEIVED,
      (payload: any) => {
        console.log('PUSH_RECEIVED payload:', payload);
        if (Platform.OS === 'android') return; // баннер уже показал нативный SDK
        const { title, body } = extractTitleBody(payload);
        displayNotification(title, body);
      }
    );

    // На первом холодном запуске токен может быть ещё не готов в момент
    // резолва startService() — приходит отдельным событием, когда готов.
    const tokenListener = eventEmitter.addListener(
      PushedEventTypes.TOKEN_UPDATED,
      (payload: any) => {
        if (payload?.token) {
          console.log('TOKEN_UPDATED payload:', payload);
          setToken(payload.token);
          setServiceActive(true);
          setIsLoading(false);
        }
      }
    );

    return () => {
      eventListener.remove();
      tokenListener.remove();
    };
  }, []);

  const copyToClipboard = () => {
    Clipboard.setString(token);
    Alert.alert('Copied!', 'Token copied to clipboard');
  };

  return (
    <View style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#1a1a1a" />
      
      {/* Логотип PUSHED */}
      <View style={styles.logoContainer}>
        <Image 
          source={require('../assets/pushed_logo.png')} 
          style={styles.logo}
          resizeMode="contain"
        />
      </View>

      {/* Service status */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Service status</Text>
        <Text style={[styles.statusText, serviceActive ? styles.activeStatus : styles.inactiveStatus]}>
          {isLoading ? 'Loading...' : serviceActive ? 'Active' : 'Service not active'}
        </Text>
      </View>

      {/* Client token */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Client token</Text>
        <Text style={styles.tokenText} numberOfLines={2} ellipsizeMode="middle">
          {token || 'No token available'}
        </Text>
        
        {token && (
          <TouchableOpacity style={styles.copyButton} onPress={copyToClipboard}>
            <View style={styles.copyIconContainer}>
              <Text style={styles.copyIcon}>📋</Text>
            </View>
            <Text style={styles.copyButtonText}>Copy token</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#1a1a1a',
    paddingHorizontal: 20,
    paddingTop: 60,
  },
  logoContainer: {
    alignItems: 'center',
    marginBottom: 60,
  },
  logo: {
    width: 200,
    height: 60,
  },
  section: {
    marginBottom: 40,
  },
  sectionTitle: {
    fontSize: 24,
    fontWeight: '600',
    color: '#ffffff',
    textAlign: 'center',
    marginBottom: 10,
  },
  statusText: {
    fontSize: 18,
    textAlign: 'center',
    fontWeight: '500',
  },
  activeStatus: {
    color: '#4CAF50',
  },
  inactiveStatus: {
    color: '#F44336',
  },
  tokenText: {
    fontSize: 14,
    color: '#ffffff',
    textAlign: 'center',
    marginBottom: 20,
    paddingHorizontal: 10,
    lineHeight: 20,
  },
  copyButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#2a2a2a',
    paddingVertical: 15,
    paddingHorizontal: 20,
    borderRadius: 12,
    marginHorizontal: 20,
  },
  copyIconContainer: {
    marginRight: 10,
  },
  copyIcon: {
    fontSize: 16,
  },
  copyButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '500',
  },
});
