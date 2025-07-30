"""
Script para ejecutar solo el procesamiento en background
sin las rutas API
"""
import os
import time
from spiffworkflow_backend import create_app

# Configurar para solo background processing
os.environ["SPIFFWORKFLOW_BACKEND_RUN_API_ENDPOINTS"] = "false"
os.environ["SPIFFWORKFLOW_BACKEND_RUN_BACKGROUND_SCHEDULER_IN_CREATE_APP"] = "true"

app = create_app()

if __name__ == "__main__":
    print("Starting background processing only...")
    print("Background scheduler is running...")
    
    # El scheduler se ejecuta en segundo plano
    # Mantener el proceso vivo
    try:
        while True:
            print("Background processing is active...")
            time.sleep(60)  # Log cada minuto
    except KeyboardInterrupt:
        print("Shutting down background processing...")