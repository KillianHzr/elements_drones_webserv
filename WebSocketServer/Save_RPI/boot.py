import network
import time

SSID = "Cudy-F00C"
PASSWORD = "70897678"

def connect_wifi():
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    wlan.connect(SSID, PASSWORD)

    print("Connexion au Wi-Fi...")
    timeout = 10
    while not wlan.isconnected() and timeout > 0:
        time.sleep(1)
        timeout -= 1

    if wlan.isconnected():
        print("Connecté ! Adresse IP :", wlan.ifconfig()[0])
    else:
        print("Échec de connexion au Wi-Fi.")

connect_wifi()

