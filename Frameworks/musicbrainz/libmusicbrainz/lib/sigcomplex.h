/*____________________________________________________________________________

  MusicBrainz -- The Internet music metadatabase 

  Portions Copyright (C) 2000 Relatable

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.
        
  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Lesser General Public License for more details.
     
  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  $Id: sigcomplex.h 427 2001-03-05 22:19:05Z robert $
____________________________________________________________________________*/

#ifndef INCLUDED_SIGCOMPLEX_H_
#define INCLUDED_SIGCOMPLEX_H
//------------------------------------
//  complex.h
//  Complex number
//  (c) Reliable Software, 1996
//------------------------------------

#include <math.h>

class Complex
{
public:
    Complex () {}
    Complex (double re): _re(re), _im(0.0) {}
    Complex (double re, double im): _re(re), _im(im) {}
    double Re () const { return _re; }
    double Im () const { return _im; }
    void operator += (const Complex& c)
    {
        _re += c._re;
        _im += c._im;
    }
    void operator -= (const Complex& c)
    {
        _re -= c._re;
        _im -= c._im;
    }
    void operator *= (const Complex& c)
    {
        double reT = c._re * _re - c._im * _im;
        _im = c._re * _im + c._im * _re;
        _re = reT;
    }
    Complex operator- () 
    {
            return Complex (-_re, -_im);
    }
    double Mod () const { return sqrt (_re * _re + _im * _im); }
    double Conjugate () const { return (_re * _re + _im * _im); }
private:
    double _re;
    double _im;
};

#endif
