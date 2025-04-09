// IBackgroundService.aidl
package com.multipushed;

interface IBackgroundService {
         boolean invoke(String data);
         void stop();
}
