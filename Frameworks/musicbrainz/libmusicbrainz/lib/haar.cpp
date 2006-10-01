#include <string.h>
#include "haar.h"

HaarWavelet::HaarWavelet(int nNumPoints, int nLevel)
{
	m_dRoot2 = 1.0 / 2.0;
	m_pTape = new double[nNumPoints];
	m_nNumPoints = nNumPoints;
	m_nLevel = nLevel;
}

HaarWavelet::~HaarWavelet()
{
	delete [] m_pTape;
}

void HaarWavelet::Transform(double* pBuf)
{
	int nMidPoint = m_nNumPoints / 2;
	int i = 0;
	int j = 0;
	// pass one to get the average vals
	for (i = 0; i < m_nNumPoints; i += 2)
	{
		m_pTape[j] = pBuf[i] + pBuf[i+1];
		m_pTape[j + nMidPoint] = pBuf[i] - pBuf[i+1];
		j++;
	}
	
	// seperate the multiply into 4 part sections, to speed up fpu usage
	for (i = 0; i < m_nNumPoints; i+=4)
	{
		m_pTape[i] *= m_dRoot2;
		m_pTape[i+1] *= m_dRoot2;
		m_pTape[i+2] *= m_dRoot2;
		m_pTape[i+3] *= m_dRoot2;
	}
	//Print();
	if (m_nLevel > 1)
	{
		int nStop = 0;
		int nLevel = 1;
		double* dTemp = new double[nMidPoint];
		while (nLevel < m_nLevel)
		{
			nStop = nMidPoint;
			nMidPoint /= 2;
			memcpy(dTemp, m_pTape, sizeof(double)*nStop);
			j = 0;
			for (i = 0; i < nStop; i+=2)
			{
				dTemp[j] = m_pTape[i] + m_pTape[i+1];
				dTemp[nMidPoint+j] = m_pTape[i] - m_pTape[i+1];
				j++;
			}
			memcpy(m_pTape, dTemp, sizeof(double)*nStop);
			
			for (i = 0; i < nStop; i += 2)
			{
				m_pTape[i] *= m_dRoot2;
				m_pTape[i+1] *= m_dRoot2;
			}
			nLevel++;
			//Print();
		}
		delete [] dTemp;
	}
}
