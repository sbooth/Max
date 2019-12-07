#pragma once

#ifdef WIN32

namespace APE
{

/*******************************************************************************************************************************
CTimer
*******************************************************************************************************************************/
class CTimer
{
public:
	CTimer()
	{
		QueryPerformanceFrequency(&m_Frequency);
		QueryPerformanceCounter(&m_Timer);
	}

	void Reset()
	{
		QueryPerformanceCounter(&m_Timer);
	}

	double GetElapsedMS(bool bReset = false)
	{
		double dElapsedMS = 0;

		// get now time
		LARGE_INTEGER Now;
		QueryPerformanceCounter(&Now);

		// get elapsed units
		int64 nElapsedUnits = Now.QuadPart - m_Timer.QuadPart;

		// get elapsed milliseconds
		if (m_Frequency.QuadPart > 0)
		{
			dElapsedMS = double(nElapsedUnits) * double(1000) / double(m_Frequency.QuadPart);
		}

		// reset
		if (bReset)
			Reset();

		return dElapsedMS;
	}

private:

	LARGE_INTEGER m_Timer;
	LARGE_INTEGER m_Frequency;
};

}

#endif