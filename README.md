# AudioCap

With macOS 14.4, Apple introduced new API in CoreAudio that allows any app to capture audio from other apps or the entire system, as long as the user has given the app permission to do so.

Unfortunately this new API is poorly documented and the nature of CoreAudio makes it really hard to figure out exactly how to set things up so that your app can use this new functionality.

This project is provided as documentation for this new API to help developers of audio apps.

https://github.com/insidegui/AudioCap/assets/67184/95d72d1f-a4d6-4544-9d2f-a2ab99507cfc




https://github.com/user-attachments/assets/efc03340-1d1c-46bc-92b4-ee6e1e763dbc






## API Description

Here’s a brief summary of the new API added in macOS 14.4 and how to put everything together.

### Permission

As you’d expect, recording audio from other apps or the entire system requires a permission prompt.

The message for this prompt is defined by adding the `NSAudioCaptureUsageDescription` key to the app’s Info.plist. This key is not listed in the Xcode dropdown, you have to enter it manually. 

There’s no public API to request audio recording permission or to check if the app has that permission. This project implements permission check/request using private API from the TCC framework, but there is a build-time flag to disable private API usage, in which case the permission will be requested the first time audio recording is started in the app.

### Process Tap Setup

Assuming the app has audio recording permission, setting up and recording audio from other apps can be done by performing the following steps:

- Get the PID of the process you wish to capture
- Use [kAudioHardwarePropertyTranslatePIDToProcessObject](https://developer.apple.com/documentation/coreaudio/kaudiohardwarepropertytranslatepidtoprocessobject) to translate the PID into an `AudioObjectID`
- Create a [CATapDescription](https://developer.apple.com/documentation/coreaudio/catapdescription) for the object ID above, and set (or just get) its `uuid` property, which will be needed later
- Call [AudioHardwareCreateProcessTap](https://developer.apple.com/documentation/coreaudio/4160724-audiohardwarecreateprocesstap) with the tap description to create the tap, which gets its own `AudioObjectID`
- Create a dictionary for your aggregate device that includes `[kAudioSubTapUIDKey: <your tap description uuid string>]` in its `kAudioAggregateDeviceTapListKey` (you probably want to configure other things, such as setting `kAudioAggregateDeviceIsPrivateKey` to true so that it doesn’t show up globally)
- Call [AudioHardwareCreateAggregateDevice](https://developer.apple.com/documentation/coreaudio/1422096-audiohardwarecreateaggregatedevi) with the dictionary above
- Read `kAudioTapPropertyFormat` from the process tap to get its `AudioStreamBasicDescription`, then create an `AVAudioFormat` matching the description, this will be needed later
- Create an `AVAudioFile` for writing with your desired settings
- Call `AudioDeviceCreateIOProcIDWithBlock` to set up a callback for your aggregate device
- Inside the callback, create an `AVAudioPCMBuffer` passing in your format; you can use `bufferListNoCopy` with `nil` deallocator then just call `write(from:)` on your audio file, passing in the buffer
- Call `AudioDeviceStart` with the aggregate device and IO proc ID
- Remember to call all your `Audio...Stop` and `Audio...Destroy` cleanup functions
- Let the `AVAudioFile` deinit to close it
- Now you have an audio file with a recording from the system or app

Thanks to [@WFT](https://github.com/WFT) for helping me with this project.
