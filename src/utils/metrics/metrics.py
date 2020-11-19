import sklearn.metrics as me


# Rank Evaluation


def precision_at_n(rank, truth, n=10):
    """
    Precision at N
    """
    try:
        r = rank[:n]
    except Exception:
        r = rank
    m = len(set(r) & set(truth)) / float(n)
    return round(m, 3)


def r_precision(rank, truth):
    """
    R-Precision
    """
    return precision_at_n(rank, truth, n=len(truth))


def maprec(rank, truth, k=None):
    """
    Mean Average Precision

    :param k: limit to the "k" top ranked documents
    """
    try:
        rank = rank[:k]
    except Exception:
        pass
    rk = []
    for i in xrange(len(rank)):
        if rank[i] in truth:
            rk.append(i + 1)
            if len(set(rk)) == len(truth):
                break
    mapr = 0.0
    if len(rk) == 0:
        return mapr
    for i in xrange(len(rk)):
        mapr += (i + 1) / float(rk[i])
    mapr /= len(rk)
    return round(mapr, 3)


def mrr(rank, truth):
    """
    Mean Reciprocal Rank
    """
    rk = len(rank)
    for i in xrange(len(rank)):
        if rank[i] in truth:
            rk = i + 1
            break
    mrr = 1 / float(rk)
    return round(mrr, 3)


# Information Retrival Classic Evaluation


def auc_roc(scores, truth):
    """
    Area Under the ROC Curve
    """
    auc_roc = me.roc_auc_score(truth, scores)
    return round(auc_roc, 3)


def precision(scores, truth):
    """
    Precision
    """
    p = me.precision_score(truth, scores)
    return round(p, 3)


def recall(scores, truth):
    """
    Recall
    """
    r = me.recall_score(truth, scores)
    return round(r, 3)


def fscore(scores, truth, beta=1):
    """
    F-score

    :param beta: precision / recall tradeoff weight
    """
    fscore = me.fbeta_score(truth, scores, beta=beta)
    return round(fscore, 3)


def accuracy(scores, truth):
    """
    Accuracy
    """
    acc = me.accuracy_score(truth, scores)
    return round(acc, 3)

def auc_pr(scores, truth):
    """
    Area under the Precision Recall curve
    """
    auc_pr = me.average_precision_score(truth, scores)
    return round(auc_pr, 3)

