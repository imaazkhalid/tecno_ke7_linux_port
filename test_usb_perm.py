import usb.core
import time

print("Waiting for 0e8d:0003 or 0e8d:2000...")
while True:
    d = usb.core.find(idVendor=0x0e8d)
    if d is not None:
        print(f"Found MTK USB device: VID=0x{d.idVendor:04x} PID=0x{d.idProduct:04x}")
        try:
            print("Manufacturer:", d.manufacturer)
            print("Product:", d.product)
            print("Serial:", d.serial_number)
            print("Configurations:", len(d.configurations))
        except Exception as e:
            print("Error accessing descriptors:", e)
        time.sleep(1)
        break
    time.sleep(0.1)
