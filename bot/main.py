"""
Punto de entrada del contenedor Docker.
Lanza bot cliente y bot admin en paralelo usando asyncio.
"""

import asyncio
import logging
import signal

from bot_cliente import build_app as build_cliente
from bot_admin import build_app as build_admin

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s"
)
logger = logging.getLogger("main")


async def run():
    app_cliente = build_cliente()
    app_admin   = build_admin()

    async with app_cliente, app_admin:
        await app_cliente.initialize()
        await app_admin.initialize()
        await app_cliente.start()
        await app_admin.start()
        await app_cliente.updater.start_polling(drop_pending_updates=True)
        await app_admin.updater.start_polling(drop_pending_updates=True)

        logger.info("✅ Bot Cliente y Bot Admin corriendo. CTRL+C para detener.")

        stop = asyncio.Event()
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, stop.set)

        await stop.wait()

        logger.info("Apagando bots...")
        await app_cliente.updater.stop()
        await app_admin.updater.stop()
        await app_cliente.stop()
        await app_admin.stop()


if __name__ == "__main__":
    asyncio.run(run())
