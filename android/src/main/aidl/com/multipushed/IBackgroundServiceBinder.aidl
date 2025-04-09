// IBackgroundServiceBinder.aidl
package com.multipushed;

import com.multipushed.IBackgroundService;

interface IBackgroundServiceBinder {
     void bind(int id, IBackgroundService service);
     void unbind(int id);
     void invoke(String data);
}
