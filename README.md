# CompetitiveProgrammerNaruseJun

C.P.N.J. is vim-plugin for competitive programmers.

## Features
- Available for **AizuOnlineJudge**, **AtCoder**, **TokyoTechCoder**
- Compatible with **C++**, **D**, **Perl**, **Ruby**
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

Add below code to your .vimrc (with NeoBundle)  
`NeoBundle 'kazsw/CompetitiveProgrammerNaruseJun'`

## Usage

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
`:Jun make abc031_a C++`  

### Test
`:Jun test`

### Submit
`:Jun submit` (Your browser will open)

## Author

~~JunNaruse ([@_naruse_jun](https://twitter.com/_naruse_jun))~~  
kazsw ([@_naruse_jun](https://twitter.com/_naruse_jun))