from sklearn.decomposition import TruncatedSVD
import numpy as np
import bisect
import csv
import os


def patient_embedding(phist,
                      embedding=None,
                      outdir=None,
                      window_length=15,
                      window_step=5,
                      algo='word2vec'):
    """
    Create patient embeddings

    @param phist: dictionary with <patient id: [clinical events sorted by date]
    @param embedding: pre-trained medical concept embeddings
    """

    if len(phist) == 0 or embedding is None:
        print 'ERROR: data missing -- Interrupting'
        return

    print 'Creating the patient sentences'
    ptn_seq, pw = _create_sentences(
        phist, embedding.wv.vocab, window_length, window_step)

    # index data
    ivcb = _index_data(embedding.wv.vocab)

    print 'Weight the embeddings based on phenotype probability'
    wemb = _weight_embedding(embedding, ivcb, pw)

    print 'Compute the patient embeddings'
    ptn_emb, pids = _sentence_average(ptn_seq, wemb, ivcb)

    print 'Denoise the patient embeddings'
    ptn_emb = _denoise_embedding(ptn_emb)

    # save as csv mrn, values
    print 'Save the embeddings'
    _save_patient_embedding(ptn_emb, pids, outdir,
                            window_length, window_step, algo)

    return ptn_emb


# private functions

def _create_sentences(phist, evocab, w_length, w_step):
    """
    Create patient longitudinal sentences. We used age_in_days as temporal
    index (replace with dates or other surrogates for time information)
    """
    ptn_seq = {}
    wprob = {w: set() for w in evocab}
    for p, ev in phist.items():
        ptn_seq[p] = []
        concepts = [el[0] for el in ev]
        age_in_days = [el[1] for el in ev]
        last_ag = []

        # create the sentences moving the time window
        begin = age_in_days[0]
        while begin <= age_in_days[-1]:
            # find the range in age_in_days
            end = begin + w_length
            il = bisect.bisect_left(age_in_days, begin)
            ir = bisect.bisect_left(age_in_days, end)

            # get data
            ag = age_in_days[il:ir]
            co = concepts[il:ir]

            # move window
            begin += w_step

            # check interval
            if len(ag) == 0:
                continue

            if ag == last_ag:
                continue

            # update last
            last_ag = ag

            # create sentence
            s = set()
            for w in co:
                if w not in evocab:
                    continue
                s.add(w)
                wprob[w].add(p)
            if len(s) > 0:
                ptn_seq[p].append(s)

    n = len(ptn_seq)
    for w, c in wprob.items():
        wprob[w] = len(c) / float(n)

    # remove frequent concepts
    stopw = set(w for w in wprob if wprob[w] > 0.5)
    ptn_sent = {}
    for p in ptn_seq:
        ps = []
        for el in ptn_seq[p]:
            s = el - stopw
            if len(s) == 0:
                continue
            ps.append(s)
        if len(ps) > 0:
            ptn_sent[p] = ps

    print 'Created %d clinical sentences' \
        % sum([len(ptn_sent[p]) for p in ptn_sent])

    return (ptn_sent, wprob)


def _weight_embedding(embs, ivcb, pw):
    """
    Weight the medical conceot embeddings to differentiate not impactful
    concepts
    """
    a = 1
    apw = {}
    for w, p in pw.items():
        apw[w] = a / (a + p)
    wemb = np.zeros([len(ivcb), embs.vector_size])
    for w in ivcb:
        ew = (embs.wv[w] - embs.wv[w].mean()) / embs.wv[w].std()
        wemb[ivcb[w], :] = ew * apw[w]
    return wemb


def _sentence_average(ptn_seq, wemb, ivcb):
    """
    Create the patient sentence embeddings
    """
    ptn_emb = []
    mrns = []
    for p in ptn_seq:
        for s in ptn_seq[p]:
            wi = [ivcb[w] for w in s]
            ptn_emb.append(np.average(wemb[wi, :], axis=0))
            mrns.append(p)
    ptn_emb = np.array(ptn_emb)
    return (ptn_emb, mrns)


def _denoise_embedding(v):
    """
    Denoise embeddings by subtracting the projections of the average vectors
    on their first principal component
    """
    u = _compute_pc(v)
    emb = v - v.dot(u.transpose()) * u
    return emb / np.max(np.abs(emb), axis=0)


def _compute_pc(x):
    """
    Compute SVD projections
    """
    svd = TruncatedSVD(n_components=1, n_iter=10, random_state=0)
    svd.fit(x)
    return svd.components_


def _index_data(dt):
    return {el: i for i, el in enumerate(dt)}


def _save_patient_embedding(emb, pids, outdir,
                            w_length, w_step, algo):
    if outdir is None:
        return
    emb = emb.astype(np.float16)

    # save embedding as csv
    out = [['PID'] + ['F%d' % i for i in xrange(emb.shape[1])]]
    for i in xrange(emb.shape[0]):
        out.append([pids[i]] + list(emb[i, :]))

    fout = os.path.join(outdir,
                        '%s-patient-embedding-%d-%d-%d.csv' %
                        (algo, emb.shape[1], w_length, w_step))

    with open(fout, 'w') as f:
        wr = csv.writer(f, quoting=csv.QUOTE_MINIMAL)
        wr.writerows(out)

    print 'Embeddings saved in: %s' % fout


"""
Main script
"""

if __name__ == '__main__':
    print ''

    # load data (patient history and medical concept embeddings)
    phist = None
    embedding = None

    patient_embedding(phist,
                      embedding,
                      outdir=None,
                      window_length=15,
                      window_step=5,
                      algo='word2vec')

    print '\nTask completed\n'
