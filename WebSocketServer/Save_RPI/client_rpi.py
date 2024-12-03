import asyncio
import threading
import time
import websockets
import json
import traceback
from sphero_sdk import SpheroRvrObserver, RawMotorModesEnum

# Adresse IP et port du Mac
MAC_IP = '192.168.10.213'
MAC_PORT = 8080
ROUTE = 'rpiConnect'

# Vitesse définie pour avancer/reculer
FORWARD_SPEED = 50  # Vitesse entre 0 et 255
TURN_SPEED = 50     # Vitesse entre 0 et 255

# Initialisation du RVR avec diagnostics approfondis
def initialize_rvr():
    try:
        rvr = SpheroRvrObserver()
        print("🤖 RVR initialisé avec succès.")
        
        # Diagnostics détaillés
        print("🔍 Vérification des capacités du RVR :")
        print(f"Méthodes disponibles : {', '.join(method for method in dir(rvr) if not method.startswith('_'))}")
        
        # Tentative de réveil avec logs
        rvr.wake()
        print("🌟 RVR réveillé")
        
        # Petit délai pour stabilisation
        time.sleep(2)
        
        return rvr
    
    except Exception as e:
        print(f"❌ Erreur d'initialisation du RVR : {type(e).__name__}")
        print(f"Message détaillé : {str(e)}")
        print(f"Trace complète : {traceback.format_exc()}")
        return None

# Initialiser le RVR
rvr = initialize_rvr()

if rvr is None:
    print("❌ Erreur : Impossible d'initialiser le RVR. Arrêt du programme.")
    exit(1)

# Variables pour la file d'attente des actions
action_queue = []
action_lock = threading.Lock()
running = True

# Définitions des actions avec diagnostics
def drive_forward():
    print(f"🚀 Tentative d'avancer - Vitesse: {FORWARD_SPEED}")
    try:
        rvr.raw_motors(
            left_mode=RawMotorModesEnum.forward.value,
            left_speed=FORWARD_SPEED,
            right_mode=RawMotorModesEnum.forward.value,
            right_speed=FORWARD_SPEED
        )
        print("✅ Commande d'avancement envoyée")
    except Exception as e:
        print(f"❌ Erreur d'avancement : {type(e).__name__} - {str(e)}")

def drive_backward():
    print(f"🔙 Tentative de recul - Vitesse: {FORWARD_SPEED}")
    try:
        rvr.raw_motors(
            left_mode=RawMotorModesEnum.reverse.value,
            left_speed=FORWARD_SPEED,
            right_mode=RawMotorModesEnum.reverse.value,
            right_speed=FORWARD_SPEED
        )
        print("✅ Commande de recul envoyée")
    except Exception as e:
        print(f"❌ Erreur de recul : {type(e).__name__} - {str(e)}")

def turn_left():
    print(f"🔄 Tentative de rotation à gauche - Vitesse: {TURN_SPEED}")
    try:
        rvr.raw_motors(
            left_mode=RawMotorModesEnum.reverse.value,
            left_speed=TURN_SPEED,
            right_mode=RawMotorModesEnum.forward.value,
            right_speed=TURN_SPEED
        )
        print("✅ Commande de rotation à gauche envoyée")
    except Exception as e:
        print(f"❌ Erreur de rotation à gauche : {type(e).__name__} - {str(e)}")

def turn_right():
    print(f"🔄 Tentative de rotation à droite - Vitesse: {TURN_SPEED}")
    try:
        rvr.raw_motors(
            left_mode=RawMotorModesEnum.forward.value,
            left_speed=TURN_SPEED,
            right_mode=RawMotorModesEnum.reverse.value,
            right_speed=TURN_SPEED
        )
        print("✅ Commande de rotation à droite envoyée")
    except Exception as e:
        print(f"❌ Erreur de rotation à droite : {type(e).__name__} - {str(e)}")

def stop():
    try:
        rvr.raw_motors(
            left_mode=RawMotorModesEnum.off.value,
            left_speed=0,
            right_mode=RawMotorModesEnum.off.value,
            right_speed=0
        )
    except Exception as e:
        print(f"❌ Erreur d'arrêt : {type(e).__name__} - {str(e)}")

ACTIONS = {
    "forward": drive_forward,
    "backward": drive_backward,
    "left": turn_left,
    "right": turn_right,
    "stop": stop,
}

# Thread pour exécuter les actions avec diagnostics détaillés
def rvr_action_thread():
    global running
    print("🚀 Thread de mouvement démarré")
    while running:
        try:
            current_action = None
            with action_lock:
                if action_queue:
                    current_action = action_queue[0]
                    print(f"🤖 Action en file d'attente : {current_action}")
                else:
                    current_action = "stop"

            if current_action and current_action in ACTIONS:
                ACTIONS[current_action]()
            else:
                print(f"❓ Action invalide : {current_action}")

        except Exception as e:
            print(f"❌ Erreur dans le thread de mouvement : {type(e).__name__} - {str(e)}")
            print(traceback.format_exc())

        time.sleep(0.1)
    
    print("🏁 Thread de mouvement terminé")

# Lancer le thread
motion_thread = threading.Thread(target=rvr_action_thread)
motion_thread.start()

# Fonctions pour gérer les actions
def press_button(action):
    """Appelé lorsqu'un bouton est pressé."""
    with action_lock:
        if action not in action_queue:
            action_queue.append(action)
            print(f"🎮 Bouton pressé : {action}")

def release_button(action):
    """Appelé lorsqu'un bouton est relâché."""
    with action_lock:
        if action in action_queue:
            action_queue.remove(action)
            print(f"🛑 Bouton relâché : {action}")

# Fonction principale de connexion
async def connect_to_mac():
    global running
    uri = f"ws://{MAC_IP}:{MAC_PORT}/{ROUTE}"

    try:
        async with websockets.connect(uri) as websocket:
            print("🔌 Connexion établie avec le Mac")
            
            # Réveiller explicitement le RVR
            rvr.wake()
            await asyncio.sleep(2)  # Attendre que le RVR soit prêt

            try:
                async for message in websocket:
                    print(f"📡 Message reçu du Mac : {message}")

                    if message == "ping":
                        await websocket.send("pong")
                        print("✅ Pong envoyé au serveur en réponse à ping")
                        continue

                    control_data = json.loads(message)
                    action = control_data.get('action', None)
                    is_pressed = control_data.get('isPressed', False)

                    # Log détaillé pour chaque commande
                    print(f"🕹️ Commande reçue - Action: {action}, État: {'Pressé' if is_pressed else 'Relâché'}")

                    if action in ACTIONS:
                        if is_pressed:
                            press_button(action)
                        else:
                            release_button(action)
                    else:
                        print(f"❌ Action inconnue : {action}")

            except websockets.ConnectionClosed:
                print("🔌 Connexion WebSocket fermée")
            except Exception as e:
                print(f"❌ Erreur de communication : {type(e).__name__} - {str(e)}")

    except Exception as e:
        print(f"❌ Erreur de connexion : {type(e).__name__} - {str(e)}")
    finally:
        # Arrêter le mouvement et fermer la connexion
        running = False
        motion_thread.join()
        rvr.close()

# Lancement de la boucle événementielle
asyncio.get_event_loop().run_until_complete(connect_to_mac())
