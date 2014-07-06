using Stage

@expect 1 == 1
@expect 1 == 2
@expect log(e) == 1.0
@expect log(e) == 2.0
@expect log(e) < 2.0
@expect log(e) >= 2.0
@expect abs(1.0 - 0.9) < 0.1

