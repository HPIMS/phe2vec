from gensim.models import FastText
import math
import logging

"""
Fasttext embeddings
"""

log = logging.getLogger(__name__)
if not len(log.handlers):
    logging.basicConfig(format='%(message)s', level=logging.INFO)


def train(sentences,
          size=200,
          window=5,
          min_count=3,
          workers=10,
          sg=0,
          hs=1,
          negative=5):

    model = FastText(sentences=sentences,
                     size=size,
                     window=window,
                     min_count=min_count,
                     workers=workers,
                     sg=sg,
                     hs=hs,
                     negative=negative)

    return model


def save(model, fout):
    try:
        model.save(fout)
    except Exception, e:
        log.error('Impossible to save the model - %s ' % str(e))


def load(fout):
    try:
        return FastText.load(fout)
    except Exception, e:
        log.error('Impossible to load the model - %s ' % str(e))
        return


def finalize(model):
    dt = model.wv
    del model
    return dt


def update(model, sentence, sg=0, hs=0, window=10):
    model.workers = int(math.ceil(model.workers / 10))
    model.window = window
    model.sg = sg
    model.hs = hs
    return model.train(sentence, total_examples=len(sentence))
