from machine import ADC, Pin
import time
import json
from websocket_client import WebSocketClient
import leds

# Configuration des broches pour le joystick
xAxis = ADC(Pin(34, Pin.IN))
xAxis.atten(xAxis.ATTN_11DB)
yAxis = ADC(Pin(35, Pin.IN))
yAxis.atten(xAxis.ATTN_11DB)
joystick_button = Pin(33, Pin.IN, Pin.PULL_UP)

# Configuration des boutons pour les étapes
synapse_button = Pin(25, Pin.IN, Pin.PULL_UP)
lsd_button = Pin(26, Pin.IN, Pin.PULL_UP)
ecstasy_button = Pin(27, Pin.IN, Pin.PULL_UP)
champi_button = Pin(14, Pin.IN, Pin.PULL_UP)

# Configuration du bouton "dessin"
dessin_button = Pin(12, Pin.IN, Pin.PULL_UP)

# Configuration des boutons pour les pinceaux
pinceau_buttons = {
    "pinceau1": Pin(18, Pin.IN, Pin.PULL_UP),
    "pinceau2": Pin(5, Pin.IN, Pin.PULL_UP),
    "pinceau3": Pin(17, Pin.IN, Pin.PULL_UP),
    "pinceau4": Pin(16, Pin.IN, Pin.PULL_UP),
    "pinceau5": Pin(4, Pin.IN, Pin.PULL_UP)
}

# Configuration du bouton pour confirmer la solution
confirm_button = Pin(15, Pin.IN, Pin.PULL_UP)
confirm_previous_state = True  # État précédent du bouton

# Variable pour stocker le dernier pinceau cliqué
last_pinceau = None

# Adresse du WebSocket server
url_iPhoneConnect = "ws://192.168.10.213:8080/iPhoneConnect"
url_controllerEsp = "ws://192.168.10.213:8080/controllerEsp"

# Instanciation des WebSocketClient pour les deux routes
ws_iPhoneConnect = WebSocketClient(url_iPhoneConnect)
ws_controllerEsp = WebSocketClient(url_controllerEsp)

# Variables pour suivre l'état des étapes et du bouton "dessin"
stages_started = {
    "Synapse": False,
    "LSD": False,
    "Ecstasy": False,
    "Champi": False
}

dessin = False  # Variable pour l'état de "dessin"

# Définir les plages de non-mouvement et le seuil de variation
NON_MOVEMENT_CENTER_X = 1850  # Valeur moyenne au repos pour X
NON_MOVEMENT_CENTER_Y = 1900  # Valeur moyenne au repos pour Y
NON_MOVEMENT_THRESHOLD = 200  # Plage autour du centre pour considérer le joystick comme immobile

# Variables pour stocker l'état précédent
previous_x = NON_MOVEMENT_CENTER_X
previous_y = NON_MOVEMENT_CENTER_Y

# Connexion aux WebSockets
if ws_iPhoneConnect.connect():
    print("Connecté au serveur WebSocket iPhoneConnect")
else:
    print("Échec de connexion au serveur WebSocket iPhoneConnect")

if ws_controllerEsp.connect():
    print("Connecté au serveur WebSocket controllerEsp")
else:
    print("Échec de connexion au serveur WebSocket controllerEsp")

try:
    while True:
        # Lecture des valeurs du joystick
        xValue = xAxis.read()
        yValue = yAxis.read()
        btnValue = joystick_button.value()

        # Vérifier si le joystick est en mouvement
        is_x_moving = abs(xValue - NON_MOVEMENT_CENTER_X) > NON_MOVEMENT_THRESHOLD
        is_y_moving = abs(yValue - NON_MOVEMENT_CENTER_Y) > NON_MOVEMENT_THRESHOLD

        if is_x_moving or is_y_moving:
            # Préparation des données au format JSON
            joystick_data = {
                "x": xValue,
                "y": yValue,
                "button": btnValue
            }

            # Envoi des données via WebSocket sur la route controllerEsp
            ws_controllerEsp.send(json.dumps(joystick_data))
            print(f"Joystick - Données envoyées : {joystick_data}")

            # Mettre à jour l'état précédent
            previous_x = xValue
            previous_y = yValue

        # Lecture des boutons pour les étapes
        if not synapse_button.value():
            if not stages_started["Synapse"]:
                msg = {"type": "updateStage", "stage": "Synapse", "action": "start"}
                ws_iPhoneConnect.send(json.dumps(msg))
                stages_started["Synapse"] = True
                print("Étape Synapse commencée")
            else:
                print("Étape Synapse déjà commencée")

        if not lsd_button.value():
            if not stages_started["LSD"]:
                msg = {"type": "updateStage", "stage": "LSD", "action": "start"}
                ws_iPhoneConnect.send(json.dumps(msg))
                stages_started["LSD"] = True
                print("Étape LSD commencée")
            else:
                print("Étape LSD déjà commencée")

        if not ecstasy_button.value():
            if not stages_started["Ecstasy"]:
                msg = {"type": "updateStage", "stage": "Ecstasy", "action": "start"}
                ws_iPhoneConnect.send(json.dumps(msg))
                stages_started["Ecstasy"] = True
                print("Étape Ecstasy commencée")
            else:
                print("Étape Ecstasy déjà commencée")

        if not champi_button.value():
            if not stages_started["Champi"]:
                msg = {"type": "updateStage", "stage": "Champi", "action": "start"}
                ws_iPhoneConnect.send(json.dumps(msg))
                stages_started["Champi"] = True
                print("Étape Champi commencée")
            else:
                print("Étape Champi déjà commencée")

        # Gestion du bouton "dessin"
        if not dessin_button.value():  # Bouton appuyé (LOW)
            if not dessin:
                dessin = True
                msg = {"type": "dessin", "action": "mouseDown"}
                ws_iPhoneConnect.send(json.dumps(msg))
                print("Dessin ON (mouseDown envoyé)")
        else:  # Bouton relâché (HIGH)
            if dessin:
                dessin = False
                msg = {"type": "dessin", "action": "mouseUp"}
                ws_iPhoneConnect.send(json.dumps(msg))
                print("Dessin OFF (mouseUp envoyé)")

        # Gestion des boutons des pinceaux (seulement si l'étape LSD est commencée)
        if stages_started["LSD"]:
            for pinceau, button in pinceau_buttons.items():
                if not button.value():  # Bouton appuyé (LOW)
                    if last_pinceau != pinceau:
                        last_pinceau = pinceau
                        msg = {"type": "pinceau", "action": "selectBrush", "brush": pinceau}
                        ws_iPhoneConnect.send(json.dumps(msg))
                        print(f"{pinceau} sélectionné")
                    break

        # Gestion du bouton pour confirmer la solution
        confirm_current_state = confirm_button.value()
        if not confirm_current_state and confirm_previous_state:  # Transition de HIGH à LOW (clic)
            msg = {"type": "updateStage", "action": "confirmSoluce"}
            ws_iPhoneConnect.send(json.dumps(msg))
            print("ConfirmSoluce envoyé")
            # Remplissage progressif
            leds.triple_white_comet_on_red(base_color=(127, 0, 0), comet_color=(255, 255, 255), comet_length=10, gap_length=15, delay=0.02)  # LEDs
            time.sleep(1)
        confirm_previous_state = confirm_current_state

        # Pause pour éviter les rebonds
        time.sleep(0.1)
except KeyboardInterrupt:
    print("Arrêt de l'envoi des données")
finally:
    ws_iPhoneConnect.close()
    ws_controllerEsp.close()
    print("Connexion WebSocket fermée")

