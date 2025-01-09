from machine import Pin, SPI
from libs.mfrc522 import MFRC522
import time
import json
from websocket_client import WebSocketClient

# Configuration des broches pour le lecteur RFID
spi_id = 0
sck = 5    # GPIO 5 pour SCK
miso = 16  # GPIO 16 pour MISO
mosi = 17  # GPIO 17 pour MOSI
cs = 18    # GPIO 18 pour CS
rst = 4    # GPIO 4 pour RST

# Initialisation du lecteur RFID
class RFIDReader:
    def __init__(self, spi_id, sck, miso, mosi, cs, rst):
        self.reader = MFRC522(spi_id=spi_id, sck=sck, miso=miso, mosi=mosi, cs=cs, rst=rst)

    def detect_tag(self):
        try:
            self.reader.init()
            (stat, tag_type) = self.reader.request(self.reader.REQIDL)
            if stat == self.reader.OK:
                (stat, uid) = self.reader.SelectTagSN()
                if stat == self.reader.OK:
                    card_id = int.from_bytes(bytes(uid), "little", False)
                    return card_id
        except Exception as e:
            print("Erreur RFID:", e)
        return None

reader = RFIDReader(spi_id, sck, miso, mosi, cs, rst)

# URL du WebSocket pour la nouvelle route "rfidEsp"
url = "ws://192.168.10.213:8080/rfidEsp"

ws = WebSocketClient(url)

try:
    print("Connexion au serveur WebSocket à l'URL :", url)
    if ws.connect():
        print("Connecté au serveur WebSocket à l'URL :", url)
    else:
        print("Échec de connexion au WebSocket à l'URL :", url)
except Exception as e:
    print("Erreur lors de la tentative de connexion :", e)

# Variable pour stocker l'ID actuel (None = pas de badge)
current_card_id = None

try:
    while True:
        card_id = reader.detect_tag()
        
        if card_id is not None:
            # Un badge est détecté
            if current_card_id != card_id:
                # Si c'est un nouveau badge (différent de l'ancien)
                current_card_id = card_id
                data = {"card_id": card_id}
                ws.send(json.dumps(data))
                print(f"Badge détecté et envoyé : {card_id}")
        else:
            # Aucun badge détecté
            if current_card_id is not None:
                # On avait un badge avant, donc il vient d'être retiré
                print(f"Badge {current_card_id} retiré")
                
                # Optionnel : si vous souhaitez envoyer un message "badge_removed"
                data = {"card_removed": current_card_id}
                ws.send(json.dumps(data))
                
                current_card_id = None
        
        time.sleep(0.2)
except KeyboardInterrupt:
    print("Arrêt du programme.")
finally:
    ws.close()
    print("Connexion WebSocket fermée.")

