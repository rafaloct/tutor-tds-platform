import iaData from './ia-cartilha.json';
import agriculturaData from './agricultura-sustentavel.json';
import educacaoFinanceiraData from './educacao-financeira.json';
import cooperativismoData from './cooperativismo.json';
import atendimentoData from './atendimento-cliente.json';
import audiovisualData from './audiovisual.json';
import economiaLarData from './economia-lar.json';
import safData from './saf.json';
import simSimaData from './sim-sima.json';

export const lessons = [
  iaData,
  agriculturaData,
  educacaoFinanceiraData,
  cooperativismoData,
  atendimentoData,
  audiovisualData,
  economiaLarData,
  safData,
  simSimaData
];

export type Lesson = typeof iaData;
