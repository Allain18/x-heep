from ..abstractions import BasePeripheral


class W25Q128JW_Controller(BasePeripheral):
    """
    W25Q128JW_CONTROLLER.

    """

    _name = "w25q128jw_controller"

    def __init__(self, address: int = None, length: int = None, cache: str = "no"):
        """
        Initialize the W25Q128JW controller peripheral.

        :param int address: The virtual (in peripheral domain) memory address of the W25Q128JW controller.
        :param int length: The length of the W25Q128JW controller.
        """
        super().__init__(address, length)

        self._cache = 0 if cache == "no" else 1

    def get_cache(self):
        """
        Get whether the cache is enabled.
        """

        return self._cache
