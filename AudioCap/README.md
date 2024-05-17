It looks like the way you capture a tap is by first creating an aggregate device that includes the tap as one of its "children".

I haven't finished my prototype yet, but the gist of the whole process is:

- Get the PID of the process you wish to capture
- Use `kAudioHardwarePropertyTranslatePIDToProcessObject` to translate the PID into an `AudioObjectID`
- Create a `CATapDescription` for the object ID above, and set (or just get) its `uuid` property, which will be needed later
- Call `AudioHardwareCreateProcessTap` with the tap description to create the tap, which gets its own `AudioObjectID`
- Create a dictionary for your aggregate device that includes `[kAudioSubTapUIDKey: <your tap description uuid string>]` in its `kAudioAggregateDeviceTapListKey` (you probably want to configure other things, such as setting `kAudioAggregateDeviceIsPrivateKey` to `true` so that it doesn't show up globally)
- Call `AudioHardwareCreateAggregateDevice` with the dictionary above
- Do whatever you have to do to capture from the device (this is the part I haven't done yet)