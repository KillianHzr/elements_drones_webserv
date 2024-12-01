import asyncio
import threading
import time
import websockets
import json
from sphero_sdk import SpheroRvrObserver, RawMotorModesEnum

# Adresse IP et port du Mac
MAC_IP = '192.168.1.24'
MAC_PORT = 8080
ROUTE = 'rpiConnect'

# Initialisez le RVR
try:
    rvr = SpheroRvrObserver()
    print("RVR initialisé avec succès.")
except Exception as e:
    print(f"Erreur lors de l'initialisation du RVR : {e}")
    rvr = None

if rvr is None:
    print("Erreur : Impossible d'initialiser le RVR. Veuillez vérifier la connexion.")
    exit(1)

# Variables pour la file d'attente des actions
action_queue = []
action_lock = threading.Lock()
running = True

# Vitesse définie pour avancer/reculer
FORWARD_SPEED = 50  # Vitesse entre 0 et 255
TURN_SPEED = 50     # Vitesse entre 0 et 255

# Définitions des actions
def drive_forward():
    rvr.raw_motors(
        left_mode=RawMotorModesEnum.forward.value,
        left_speed=FORWARD_SPEED,
        right_mode=RawMotorModesEnum.forward.value,
        right_speed=FORWARD_SPEED
    )

def drive_backward():
    rvr.raw_motors(
        left_mode=RawMotorModesEnum.reverse.value,
        left_speed=FORWARD_SPEED,
        right_mode=RawMotorModesEnum.reverse.value,
        right_speed=FORWARD_SPEED
    )

def turn_left():
    rvr.raw_motors(
        left_mode=RawMotorModesEnum.reverse.value,
        left_speed=TURN_SPEED,
        right_mode=RawMotorModesEnum.forward.value,
        right_speed=TURN_SPEED
    )

def turn_right():
    rvr.raw_motors(
        left_mode=RawMotorModesEnum.forward.value,
        left_speed=TURN_SPEED,
        right_mode=RawMotorModesEnum.reverse.value,
        right_speed=TURN_SPEED
    )

def stop():
    rvr.raw_motors(
        left_mode=RawMotorModesEnum.off.value,
        left_speed=0,
        right_mode=RawMotorModesEnum.off.value,
        right_speed=0
    )

ACTIONS = {
    "forward": drive_forward,
    "backward": drive_backward,
    "left": turn_left,
    "right": turn_right,
    "stop": stop,
}

# Thread pour exécuter les actions
def rvr_action_thread():
    global running
    while running:
        current_action = None
        with action_lock:
            if action_queue:
                current_action = action_queue[0]
            else:
                current_action = "stop"  # Si aucune action, arrêter le RVR

        if current_action:
            try:
                ACTIONS[current_action]()
            except Exception as e:
                print(f"Erreur lors de l'exécution de l'action '{current_action}' : {e}")

        time.sleep(0.1)  # Répéter à une fréquence de 10 Hz

# Lancer le thread
motion_thread = threading.Thread(target=rvr_action_thread)
motion_thread.start()

# Fonctions pour gérer les actions
def press_button(action):
    """Appelé lorsqu'un bouton est pressé."""
    with action_lock:
        if action not in action_queue:
            action_queue.append(action)

def release_button(action):
    """Appelé lorsqu'un bouton est relâché."""
    with action_lock:
        if action in action_queue:
            action_queue.remove(action)

async def connect_to_mac():
    global running
    uri = f"ws://{MAC_IP}:{MAC_PORT}/{ROUTE}"

    async with websockets.connect(uri) as websocket:
        print("Connexion établie avec le Mac")
        rvr.wake()
        await asyncio.sleep(2)  # Attendre que le RVR soit prêt

        try:
            async for message in websocket:
                print(f"Message reçu du Mac : {message}")
                control_data = json.loads(message)
                action = control_data.get('action', None)
                is_pressed = control_data.get('isPressed', False)

                if action in ACTIONS:
                    if is_pressed:
                        press_button(action)
                    else:
                        release_button(action)
                else:
                    print(f"Action inconnue : {action}")

        except websockets.ConnectionClosed:
            print("Connexion fermée")
        finally:
            # Arrêter le mouvement et fermer la connexion
            running = False
            motion_thread.join()
            rvr.close()

asyncio.get_event_loop().run_until_complete(connect_to_mac())

