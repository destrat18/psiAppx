import std.uni, std.array, std.string, std.conv, std.algorithm, std.range;
import dexpr,util;

DExpr dParse(string s){ // TODO: this is work in progress, usually updated in order to speed up debugging
	struct DParser{
		string code;
		void skipWhitespace(){
			while(!code.empty&&code.front.isWhite())
				next();
		}
		dchar cur(){
			skipWhitespace();
			if(code.empty) return 0;
			return code.front;
		}
		void next(){ code.popFront(); }
		void expect(dchar c){
			if(cur()==c) next();
			else throw new Exception("expected '"~to!string(c)~"' at \""~code~"\"");
		}
		
		DExpr parseDIvr(){
			expect('[');
			auto exp=parseDExpr();
			DIvr.Type ty;
			void doIt(DIvr.Type t){
				next();
				if(cur()=='0') expect('0');
				else exp=exp-parseDExpr();
				ty=t;
			}
			switch(cur()) with(DIvr.Type){
				case '=': doIt(eqZ); break;
				case '≠': doIt(neqZ); break;
				case '<': doIt(lZ); break;
				case '≤': doIt(leZ); break;
				default: expect('<'); assert(0);
			}
			expect(']');
			return dIvr(ty,exp);
		}
		DExpr parseDDelta(){
			expect('δ');
			expect('[');
			auto expr=parseDExpr();
			expect(']');
			return dDelta(expr);
		}
		
		DExpr parseSqrt(){
			expect('√');
			string arg;
			dchar cur=0;
			string tmp=code;
			for(int i=0;!tmp.empty;){
				dchar c=tmp.front;
				if(i&1){
					if(c=='̅'){
						arg~=cur;
					}else break;
				}else cur=c;
				tmp.popFront();
				if(i&1) code=tmp;
				i++;
			}
			return dParse(arg)^^(one/2);
		}

		DExpr parseLog()in{assert(code.startsWith("log"));}body{
			code=code["log".length..$];
			expect('(');
			auto e=parseDExpr();
			expect(')');
			return dLog(e);
		}

		DExpr parseGaussInt()in{assert(code.startsWith("(d/dx)⁻¹[e^(-x²)]"));}body{
			code=code["(d/dx)⁻¹[e^(-x²)]".length..$];
			expect('(');
			auto e=parseDExpr();
			expect(')');
			return dGaussInt(e);
		}

		DExpr parseDInt(){
			expect('∫');
			expect('d');
			auto iVar=parseDVar();
			auto iExp=parseMult();
			return dInt(iVar,iExp);
		}

		DExpr parseLim()in{assert(code.startsWith("lim"));}body{
			code=code["lim".length..$];
			expect('[');
			auto var=parseDVar();
			expect('→');
			auto e=parseDExpr();
			expect(']');
			auto x=parseMult();
			return dLim(var,e,x);
		}

		DExpr parseNumber()in{assert('0'<=cur()&&cur()<='9');}body{
			ℕ r=0;
			while('0'<=cur()&&cur()<='9'){
				r=r*10+cast(int)(cur()-'0');
				next();
			}
			if(cur()=='.'){
				string s="0.";
				for(next();'0'<=cur()&&cur()<='9';next()) s~=cur();
				return (s.to!double+toDouble(r)).dFloat; // TODO: this is a hack
			}
			return dℕ(r);
		}

		bool isIdentifierChar(dchar c){
			if(c=='δ') return false; // TODO: this is quite crude
			if(c.isAlpha()) return true;
			if(lowDigits.canFind(c)) return true;
			return false;
		}

		string parseIdentifier(){
			skipWhitespace();
			string r;
			while(!code.empty&&(isIdentifierChar(code.front)||!r.empty&&'0'<=code.front()&&code.front<='9')){
				r~=code.front;
				code.popFront();
			}
			if(r=="") expect('ξ');
			return r;
		}

		DVar parseDVar(){
			string s=parseIdentifier();
			return dVar(s);
		}
		DExpr parseDVarDFun(){
			string s=parseIdentifier();
			if(cur()!='(') return dVar(s);
			DExpr[] args;
			do{
				next();
				if(cur()!=')') args~=parseDExpr();
			}while(cur()==',');
			expect(')');
			return dFun(dFunVar(s),args);
		}

		DExpr parseBase(){
			if(code.startsWith("(d/dx)⁻¹[e^(-x²)]")) return parseGaussInt();
			if(cur()=='('){
				next();
				auto r=parseDExpr();
				expect(')');
				return r;
			}
			if(cur()=='∞'){ next(); return dInf; }
			if(cur()=='[') return parseDIvr();
			if(cur()=='δ') return parseDDelta();
			if(cur()=='∫') return parseDInt();
			if(cur()=='√') return parseSqrt();
			if(code.startsWith("log")) return parseLog();
			if(code.startsWith("lim")) return parseLim();
			if(cur()=='⅟'){
				next();
				return 1/parseFactor();
			}
			if('0'<=cur()&&cur()<='9')
				return parseNumber();
			if(cur()=='e'){
				next();
				return dE;
			}
			if(cur()=='π'){
				next();
				return dΠ;
			}
			return parseDVarDFun();
		}

		DExpr parseDPow(){
			DExpr e=parseBase();
			if(cur()=='^'){
				next();
				return e^^parseFactor();
			}
			ℕ exp=0;
			if(highDigits.canFind(cur())){
				do{
					exp=10*exp+highDigits.indexOf(cur());
					next();
				}while(highDigits.canFind(cur));
				return e^^exp;
			}
			return e;
		}

		DExpr parseFactor(){
			if(cur()=='-'){
				next();
				return -parseFactor();
			}
			return parseDPow();
		}

		bool isMultChar(dchar c){
			return "·*"d.canFind(c);
		}
		bool isDivChar(dchar c){
			return "÷/"d.canFind(c);
		}

		DExpr parseMult(){
			DExpr f=parseFactor();
			while(isMultChar(cur())||isDivChar(cur())){
				if(isMultChar(cur())){
					next();
					f=f*parseFactor();
				}else{
					next();
					f=f/parseFactor();
				}
			}
			return f;
		}

		DExpr parseAdd(){
			DExpr s=parseMult();
			while(cur()=='+'||cur()=='-'){
				auto x=cur();
				next();
				auto c=parseMult();
				if(x=='-') c=-c;
				s=s+c;
			}
			return s;
		}

		DExpr parseDExpr(){
			return parseAdd();
		}
	}
	return DParser(s).parseDExpr();
}
