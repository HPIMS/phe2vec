from gensim.matutils import corpus2csc
from gensim.corpora import Dictionary
from gensim.models import KeyedVectors
import numpy as np
import logging
import glove

log = logging.getLogger(__name__)
if not len(log.handlers):
    logging.basicConfig(format='%(message)s', level=logging.INFO)

"""
GloVe embeddings
"""


def train(sentences,
          size=200,
          window=5,
          min_count=3,
          workers=5):

    # filter the vocabulary
    vcb = {}
    for s in sentences:
        for w in s:
            vcb.setdefault(w, 0)
            vcb[w] += 1
    vocab = set(w for w in vcb if vcb[w] >= min_count)

    # pre-process the sentences
    corpus = []
    for s in sentences:
        c = vocab & set(s)
        if len(c) > 1:
            corpus.append(list(c))

    # create the BoW matrix
    dct = Dictionary(corpus)
    bow = [dct.doc2bow(el) for el in corpus]
    td_mtx = corpus2csc(bow)

    # vocabulary indices
    ivcb = dct.token2id
    iivcb = {v: k for k, v in ivcb.items()}

    # create the co-occurrence matrix
    tt_mtx = np.dot(td_mtx, td_mtx.T)

    # create the co-occurrence dictionary
    co = dict(tt_mtx.todok())
    co_occur = {}
    for c in co:
        co_occur.setdefault(c[0], {})
        co_occur[c[0]][c[1]] = co[c]

    # train Glove embeddings
    model = glove.Glove(co_occur, d=size, alpha=0.1, x_max=5000)
    epoch = 0
    while True:
        epoch += 1
        err = model.train(step_size=0.1, workers=workers,
                          batch_size=128, verbose=False)
        print "Epoch %d: error = %.3f" % (epoch, err)
        if err < 0.1:
            break

    # create vector objects
    kv = KeyedVectors(size)
    words = [iivcb[i] for i in xrange(len(model.W))]
    kv.add(entities=words, weights=model.W)

    return kv


def save(model, fout):
    try:
        model.save(fout)
    except Exception, e:
        log.error('Impossible to save the model - %s ' % str(e))


def load(fout):
    try:
        return KeyedVectors.load(fout)
    except Exception, e:
        log.error('Impossible to load the model - %s ' % str(e))
        return
