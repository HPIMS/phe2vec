from scipy.spatial.distance import cdist
from utils import metrics as me
import numpy as np
import os
import warnings


warnings.simplefilter(action='ignore', category=FutureWarning)
warnings.simplefilter(action='ignore', category=RuntimeWarning)

metrics = ['Precision', 'Recall', 'F-score',
           'Prec@10', 'Prec@r', 'MAP', 'AUC-ROC', 'AUC-PR']


def eval_embedding(eptn,
                   pidx,
                   evcb,
                   gt_pheno,
                   outdir=None):
    """
    Evaluate pre-loaded phe2vec representantions for disease cohort retrieval

    @param eptn: patient embeddings
    @param pidx: patient index (<MRN: dataset ID>)
    @param evcb: medical concept embedding model
    @param gt_pheno: ground truth based on PheKB {<disease: [MRNs]}
    """

    # create output directory
    if outdir is not None:
        if not os.path.isdir(outdir):
            os.makedirs(outdir)

    # evaluation
    results = {m: [] for m in metrics}
    for ph in sorted(gt_pheno):
        print 'Processing:', ph
        print '--- Query Seed:', ', '.join(gt_pheno[ph]['seed'])

        # create query
        qv, ql, qexp = _define_query_vector(
            evcb, gt_pheno[ph]['seed'], expand=True)
        if qv is None:
            continue

        # compute distance between queries and patient sentences
        edist = cdist(qv, eptn, metric='cosine')

        # aggregate the query distance values
        sdist = _aggregate_dist(edist)

        # aggregate patient sentence distances
        pdist, imrn = _aggregate_sentences(sdist, pidx)

        # ranking
        ptn_rnk = [(imrn[r], pdist[r]) for r in np.argsort(pdist)]

        # evaluation
        _evaluation(ptn_rnk, ph, gt_pheno[ph], results)

    _print_average(results)

    return


# private functions

def _define_query_vector(epheno, query_seed, expand=True):
    """
    Define the disease phenotype using distance analysis in the embedded space
    """
    eq = []
    ql = []
    qexp = {q: [] for q in query_seed}
    for q in query_seed:
        try:
            eq.append(epheno[q])
            ql.append(q)
        except Exception:
            continue
        if not expand:
            continue
        msim = epheno.most_similar(positive=[q], topn=500)
        for m in msim:
            if m[1] > 0.7:
                eq.append(epheno[m[0]])
                qexp[q].append(m[0])
                ql.append(m[0])

    if len(eq) == 0:
        return

    return (np.array(eq), ql, qexp)


def _aggregate_dist(edist):
    """
    Aggregate using mean the PSE - phenotype distances
    """
    dist = np.mean(edist, axis=0)
    return dist


def _aggregate_sentences(sent_dist, pidx):
    """
    Aggregate usin min the PSE - phenotype element distances
    """
    pdist = np.empty(shape=len(pidx))
    imrn = {}
    for i, p in enumerate(pidx):
        imrn[i] = p
        iptn = pidx[p]
        pdist[i] = np.min(sent_dist[list(iptn)])
    return (pdist, imrn)


def _evaluation(ptn_rnk, ph, gt, results):
    """
    Evaluation
    """
    print '--- No. of cases: %d' % (len(gt))

    # organize data
    iimrn = {ptn_rnk[i][0]: i for i in xrange(len(ptn_rnk))}
    pprob = np.array([p[1] for p in ptn_rnk])
    pprob = np.exp(-pprob).round(5)

    # define threshold (this should be defined via cross-validation)
    th = 0.5

    # define truth vector
    bprob = np.zeros(len(pprob))
    bprob[pprob > th] = 1
    truth = np.zeros(len(pprob))
    ipos = [iimrn[p] for p in gt]
    truth[ipos] = 1

    # annotation
    results['Precision'].append(me.precision(bprob, truth))
    print '--- Precision = %.3f' % results['Precision'][-1]
    results['Recall'].append(me.recall(bprob, truth))
    print '--- Recall = %.3f' % results['Recall'][-1]
    results['F-score'].append(me.fscore(bprob, truth))
    print '--- F-score = %.3f' % results['F-score'][-1]

    # ranking
    mrns = [r[0] for r in ptn_rnk]
    results['Prec@10'].append(me.precision_at_n(mrns, gt, 10))
    print '--- Prec@10 = %.3f' % results['Prec@10'][-1]
    results['Prec@r'].append(me.r_precision(mrns, gt))
    print '--- Prec@r = %.3f' % results['Prec@r'][-1]
    results['MAP'].append(me.maprec(mrns, gt))
    print '--- MAP = %.3f' % results['MAP'][-1]
    try:
        results['AUC-ROC'].append(me.auc_roc(pprob, truth))
    except Exception:
        results['AUC-ROC'].append(0.5)
    print '--- AUC-ROC = %.3f\n' % results['AUC-ROC'][-1]
    results['AUC-PR'].append(me.auc_pr(bprob, truth))
    print '--- AUC-PR = %.3f' % results['AUC-PR'][-1]

    return


def _print_average(results):
    print '\nAverage'
    print '--- Precision = %.3f' % np.mean(results['Precision'])
    print '--- Recall = %.3f' % np.mean(results['Recall'])
    print '--- F-score = %.3f' % np.mean(results['F-score'])
    print '--- Prec@10 = %.3f' % np.mean(results['Prec@10'])
    print '--- Prec@r = %.3f' % np.mean(results['Prec@r'])
    print '--- MAP = %.3f' % np.mean(results['MAP'])
    print '--- AUC-ROC = %.3f' % np.mean(results['AUC-ROC'])
    print '--- AUC-PR = %.3f' % np.mean(results['AUC-PR'])


def _invert_index(idx):
    return {i[1]: i[0] for i in idx.items()}


# main function

if __name__ == '__main__':
    print ''

    # load data
    eptn = None
    pidx = None
    evcb = None
    gt_pheno = None

    eval_embedding(eptn,
                   pidx,
                   evcb,
                   gt_pheno,
                   outdir=None)

    print '\nTask completed\n'
