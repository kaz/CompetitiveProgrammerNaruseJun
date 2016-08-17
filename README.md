# CompetitiveProgrammerNaruseJun

C.P.N.J. is vim-plugin for competitive programmers.

## Features
- Available for **AizuOnlineJudge**, **AtCoder**, **TokyoTechCoder**
- Compatible with **C++**, **D**, **Perl**, **Ruby**, **Python2**, **Python3**, and more
- Fetch test case
- Auto testing
- Submit source code

## Requirements
- Vim
- Perl
- Some CPAN libraries
 - WWW::Mechanize
 - LWP::Protocol::https
 - Browser::Open

Run `cpan install WWW::Mechanize LWP::Protocol::https Browser::Open`

## Install

Add below code to your **.vimrc** (with NeoBundle)
`NeoBundle 'kazsw/CompetitiveProgrammerNaruseJun'`

## Usage

### Configuration
`:Jun config` (Prompt)
`:Jun config AOJ` (Prompt)
`:Jun config AC [AtCoderID] [AtCoderPassword]`

### Setup
`:Jun setup` (Prompt)
`:Jun setup AOJ` (Prompt)
`:Jun setup AC` (Prompt)
`:Jun setup TTC` (Prompt)
`:Jun setup AOJ 0001`
`:Jun setup AC abc031`
`:Jun setup TTC 151203`

### Start coding
`:Jun make` (Prompt)
`:Jun make aoj0001` (Prompt)
`:Jun make abc031_a Python2`

### Test
`:Jun test`
`:Jun test 1`

### Submit
`:Jun submit` (Your browser will open)

## Author

NaruseJun ([@N4RU5E](https://twitter.com/N4RU5E))
