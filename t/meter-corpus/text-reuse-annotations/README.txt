= Datasets =

Wikipedia Rewrite Corpus (Clough and Stevenson, 2011). The dataset contains 100 pairs of short texts (193 words on average). For each of 5 questions about topics of computer science (e.g. “What is dynamic programming?”), a reference answer (source text, henceforth) has been manually created by copying portions of text from a suitable Wikipedia article. Text reuse now occurs between a source text and an answer given by one of 19 participants. The participants were asked to provide short answers, each of which should comply to one of 4 rewrite levels and hence reuse the source text to a varying extent. According to the degree of rewrite, the dataset is 4-way classified as cut & paste (38 texts; simple copy of text portions from the Wikipedia article), light revision (19; synonym substitutions and changes of grammatical structure allowed), heavy revision (19; rephrasing of Wikipedia excerpts using different words and structure), and no plagiarism (19; answer written independently from the Wikipedia article).

METER Corpus (Gaizauskas et al., 2001). The dataset contains news sources from the UK Press Association (PA) and newspaper articles from 9 British newspapers that reused the PA source texts to generate their own texts. The complete dataset contains 1,716 texts from two domains: law & court and show business. All newspaper articles have been annotated whether they are wholly derived from the PA sources (i.e. the PA text has been used exclusively as text reuse source), partially derived (the PA text has been used in addition to other sources), or non-derived (the PA text has not been used at all). Several newspaper texts, though, have more than a single PA source in the original dataset where it is unclear which (if not all) of the source stories have been used to generate the rewritten story. However, for text reuse detection it is important to have aligned pairs of reused texts and source texts. Therefore, we followed Sánchez-Vega et al. (2010) and selected a subset of texts where only a single source story is present in the dataset. This leaves 253 pairs of short texts (205 words on average). We further followed Sánchez-Vega et al. (2010) and folded the annotations to a binary classification of 181 reused (wholly/partially derived) and 72 non-reused instances in order to carry out a comparable evaluation study.


= Annotation Study =

In both datasets, all texts were judged by only a single person. In order to gain further insights into the data, and especially for studying the inter-rater agreement between multiple judges, we conducted annotation studies on both datasets. We asked 3 participants to rate the degree of text reuse and provided them with the original annotation guidelines.


= Scores =

The accompanying text files 'wikipedia-rewrite-corpus.csv' and 'meter-corpus.csv' contain the human judgments collected by us (columns "rater[X]") along with the original scores ("gold") by Clough and Stevenson (2011) and Gaizauskas et al. (2001), respectively. The rated text is indicated in the column "id".


= Citation =

If you use this data in your publications, please cite:

Daniel Bär, Torsten Zesch, and Iryna Gurevych. Text Reuse Detection Using a Composition of Text Similarity Measures. In Proceedings of the 24th International Conference on Computational Linguistics, December 2012, Mumbai, India.


= References = 

Paul Clough and Mark Stevenson. 2011. Developing a corpus of plagiarised short answers. Language Resources and Evaluation: Special Issue on Plagiarism and Authorship Analysis, 45(1):5-24.

Robert Gaizauskas, Jonathan Foster, Yorick Wilks, John Arundel, Paul Clough, and Scott Piao. 2001. The METER Corpus: A corpus for analysing journalistic text reuse. In Proceedings of the Corpus Linguistics 2001 Conference, pages 214-223.

Fernando Sánchez-Vega, Luis Villaseñor-Pineda, Manuel Montes-y-Gómez, and Paolo Rosso. 2010. Towards document plagiarism detection based on the relevance and fragmentation of the reused text. In Proceedings of the 9th Mexican International Conference on Artificial Intelligence, pages 24-31.

