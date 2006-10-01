#ifndef HAAR_H
#define HAAR_H

#include <iostream>
#include <math.h>

using namespace std;

class HaarWavelet
{
public:
	HaarWavelet(int nNumPoints, int nLevel = 1);
	~HaarWavelet();
	
	void SetLevel(int nLevel) { m_nLevel = nLevel; }

	void Transform(double* pBuf);
	double GetCoef(int nPoint)
	{
		return m_pTape[nPoint];
	}
#ifdef DEBUG
	void Print()
	{
		for (int i = 0; i < m_nNumPoints; i++)
		{
			cout << i << " : " << m_pTape[i] << endl;
		}
	}
#endif
private:
	double m_dRoot2;
	double* m_pTape;
	int m_nNumPoints;
	int m_nLevel;

};


#endif
