import word2vec
import fasttext
import gloveloc
import numpy as np
import logging
import bisect
import os
import random
import warnings

warnings.simplefilter(action='ignore', category=FutureWarning)
log = logging.getLogger(__name__)


def ehr_embedding(phist,
                  vocab,
                  window_length=15,
                  window_step=5,
                  min_pheno=3,
                  evalfile=None,
                  knn=50,
                  outdir=None,
                  emb_size=200,
                  workers=20,
                  algo='word2vec'
                  ):
    """
    Run word embedding on sequential EHRS

    @param phist: dictionary with <patient id: [clinical events sorted by date]
    @param vocab: dictionary mapping concept IDs to label
    """

    # create the sentences
    ehr_sentences = _create_sentences(
        phist, window_length, window_step)

    # choose model
    log.info('Embedding algorithm: %s' % algo)
    if algo == 'fasttext':
        model = fasttext
    elif algo == 'glove':
        model = gloveloc
    else:
        model = word2vec

    # train
    phemb = model.train(sentences=ehr_sentences,
                        size=emb_size,
                        window=5,
                        min_count=3,
                        workers=workers)

    # save the model
    if outdir is not None:
        try:
            os.mkdir(outdir)
        except Exception:
            pass
        fout = os.path.join(
            outdir, '%s-pheno-embedding-%d.emb' % (algo, emb_size))
        model.save(phemb, fout)

    if evalfile is not None:
        ehr_evaluation(phemb=phemb, evalfile=evalfile, knn=knn)

    return phemb


def ehr_evaluation(emb=None, gtfile=None, evalemb=None,
                   evalfile=None, knn=50):
    """
    Evaluate medical concept embeddings using ICD code hierarchies from
    the clinical classification system

    @param evalfile: file with the medical concept ontology used for
    evaluation (e.g., Clinical Classification System, SNOMED)
    """

    # load data from evalfile as {ICD: <ICD in the same ontology group>}
    evalemb = {}

    return _evaluation(emb, evalemb, knn)


# private functions

def _create_sentences(phist, w_length, w_step):
    """
    Create patient longitudinal sentences. We used age_in_days as temporal
    index (replace with dates or other surrogates for time information)
    """
    log.info('Creating sentences from the EHRs')
    sentences = []
    for p, ev in phist.items():
        concepts = [el[0] for el in ev]
        age_in_days = [el[1] for el in ev]
        last_ag = []
        last_co = []

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

            if len(ag) == 1 and len(last_co) > 0:
                step_back = ag[0] - w_length * 3
                if step_back <= last_ag[-1]:
                    ag = last_ag + ag
                    co = last_co + co

            # update last
            last_ag = ag
            last_co = co

            # create sentence
            s = list(set(co))
            random.shuffle(s)
            sentences.append(s)

    log.info('Created %d sentences' % len(sentences))
    return sentences


def _evaluation(phemb, evalemb, level='lvl1', knn=50):
    """
    Medical concept embeddings based on Clinical Classification System
    and hierarchy level equalt to 1
    """
    gt_categ = {}
    for v, it in evalemb.items():
        if 'unclassified' in it[level] or len(it[level]) == 0:
            continue
        gt_categ.setdefault(it[level], set()).add(v)

    print log.info('Category for the evaluation: %d' % len(gt_categ))

    topn = knn * 4
    mpr = []
    p10 = []
    for v in phemb.wv.vocab:
        tkn = v.split('::')
        if tkn[0] != 'icd9':
            continue

        if len(tkn) < 3:
            continue

        if tkn[2] not in evalemb:
            continue

        ctg = evalemb[tkn[2]][level]
        if ctg not in gt_categ:
            continue

        phenosim = phemb.most_similar(positive=[v], topn=topn)
        rank = []
        for c in phenosim:
            try:
                ph = c[0].split('::')[2]
            except Exception:
                continue
            if ph in evalemb:
                rank.append(evalemb[ph][level])
        rank = rank[:knn]
        mpr.append(_maprec(rank, ctg))
        p10.append(_prec_at_k(rank, ctg, 10))

    maprec = round(np.mean(mpr), 3)
    prec10 = round(np.mean(p10), 3)
    log.info('Evaluation on %d ICD-9 codes' % len(p10))
    log.info('Mean Average Precision = %.3f' % maprec)
    log.info('Precision at 10 = %.3f' % prec10)

    return {'MAP': maprec, 'P10': prec10}


def _maprec(rank, truth):
    """
    Mean average precision
    """
    pr = []
    relev = 0
    for i, w in enumerate(rank):
        if w == truth:
            relev += 1
            pr.append(relev / float(i + 1))
    if len(pr) == 0:
        return 0.0
    return np.mean(pr)


def _prec_at_k(rank, truth, k):
    """
    Precision at k
    """
    relev = 0
    for r in rank[:k]:
        if r == truth:
            relev += 1
    return relev / float(k)


"""
Main script
"""

if __name__ == '__main__':
    print ''

    # load data (patient history and medical concept embeddings)
    phist = None
    vocab = None

    ehr_embedding(phist,
                  vocab,
                  window_length=15,
                  window_step=5,
                  min_pheno=3,
                  evalfile=None,
                  knn=50,
                  outdir=None,
                  emb_size=200,
                  workers=20,
                  algo='word2vec'
                  )

    print '\nTask completed\n'
