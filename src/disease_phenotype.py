import numpy as np
import csv
import os
import warnings

warnings.simplefilter(action='ignore', category=FutureWarning)
warnings.simplefilter(action='ignore', category=RuntimeWarning)


def disease_phenotype(evcb, outdir):
    """
    Compute disease phenotypes (top 100 concepts) for all ICD-9 codes
    in the vocabulary

    @param evcb: pre-trained medical concept embeddings
    """

    # create output directory
    try:
        os.makedirs(outdir)
    except Exception:
        pass

    # load ICD9 vocabulary
    icd_vcb = _define_icd_vocab(evcb.vocab)
    print 'Loaded %d unique ICD-9 codes' % len(icd_vcb)

    # phentoype using one ICD-9 code as seed query
    phenotypes = []
    print 'Phenotype using every ICD-9 code as seed query'
    for i, code in enumerate(sorted(icd_vcb)):
        # log
        if (i + 1) % 500 == 0:
            print '-- processed %d codes' % (i + 1)

        # create query
        if not isinstance(icd_vcb[code], list):
            seed = [icd_vcb[code]]
        else:
            seed = icd_vcb[code]
        try:
            qv, ql, phe = _define_query_vector(evcb, seed)
        except Exception:
            continue

        # update phenotype list
        phenotypes += phe

    # save phenotypes
    out = [['SEED', 'SIMILAR CONCEPTS', 'COSINE SIMILARITY']] + phenotypes
    outfile = '%s/icd9-phenotypes.csv' % outdir
    _write_csv(outfile, out)

    # save ICD-9 vocab
    outfile = '%s/icd9-vocab.csv' % outdir
    out = [['CODE', 'LABEL']] + sorted(icd_vcb.items())
    _write_csv(outfile, out)

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
        msim = epheno.most_similar(positive=[q], topn=100)
        for m in msim:
            eq.append(epheno[m[0]])
            qexp[q].append(m[0])
            ql.append(m[0])

    if len(eq) == 0:
        return

    return (np.array(eq), ql, qexp)


def _define_icd_vocab(vcb):
    """
    Define the ICd-9 code vocabulary
    """
    icd_vcb = {}
    for v in vcb:
        if not v.startswith('icd9'):
            continue
        tkn = v.split('::')
        try:
            code = tkn[2]
        except Exception:
            continue
        icd_vcb[code] = v
    return icd_vcb


def _write_csv(outfile, data):
    with open(outfile, 'wb') as f:
        wr = csv.writer(f)
        wr.writerows(data)


# main function

if __name__ == '__main__':
    print ''

    # paramters
    evcb = None
    outdir = None

    disease_phenotype(evcb, outdir)

    print '\nTask completed\n'
