import logging


def config_log():
    """
    Configure the logging format
    """
    logging.basicConfig(format='%(asctime)s %(levelname)s: %(message)s',
                        datefmt='%m/%d/%Y %I:%M:%S',
                        level=logging.INFO)
