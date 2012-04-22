con <- dbConnect(PostgreSQL(), dbname="planar_development")
rs <- dbSendQuery(con, "select initiated_at, kind from cases")
data <- fetch(rs, n = -1)
attach(data)

plot(initiated_at, initiated_at, col=rgb(0,0,0,20,maxColorValue=255), cex=0.1, pch=16)


h <- hist(initiated_at, breaks=400)


---

byggsesaker


con <- dbConnect(PostgreSQL(), dbname="planar_development")
rs <- dbSendQuery(con, "select initiated_at, kind from cases where kind = 'Byggesak'")
data <- fetch(rs, n = -1)
attach(data)

h <- hist(initiated_at, breaks="months", main="Byggesaker per måned")
h <- hist(initiated_at, breaks="years", main="Byggesaker per måned")

----

scatterplot av koresspondanse og saker
--------------------------------------





# ** SQL **


con <- dbConnect(PostgreSQL(), dbname="planar_development")
rs <- dbSendQuery(con, "select initiated_at, kind from cases")
cases <- fetch(rs, n = -1)


# SETUP - ** COLS **

alpha <- 30
nice_cols <- c(rgb(50,68,82,alpha, maxColorValue=255), rgb(151,189,191, alpha, maxColorValue=255), rgb(242,223,187, alpha, maxColorValue=255), rgb(242,135,5, alpha, maxColorValue=255))
palette(nice_cols)
kinds <- c("Byggesak", "Forespørsel", "Måle-/delesak", "Plansaker")
par(lwd=0.5)


# ** EXCHANGES **
con <- dbConnect(PostgreSQL(), dbname="planar_development")
rs <- dbSendQuery(con, "select cases.initiated_at as case_date, exchanges.journal_date as exchange_date, cases.kind from exchanges join cases on case_document_id = cases.document_id")
exchanges <- fetch(rs, n = -1)

# ** EXCHANGES OUTGOING **
con <- dbConnect(PostgreSQL(), dbname="planar_development")
rs <- dbSendQuery(con, "select cases.initiated_at as case_date, exchanges.journal_date as exchange_date, cases.kind, row_number() OVER ( order by initiated_at) from exchanges join cases on case_document_id = cases.document_id")
exchanges <- fetch(rs, n = -1)

# ** EXCHANGES WITH ROW NUMBERS **
con <- dbConnect(PostgreSQL(), dbname="planar_development")
rs <- dbSendQuery(con, "select cases.initiated_at as case_date, exchanges.journal_date as exchange_date, cases.kind, rank() OVER (order by initiated_at) from exchanges join cases on case_document_id = cases.document_id order by case_date asc")
exchanges <- fetch(rs, n = -1)

# ** EXCHANGES WITH ROW NUMBERS 'BYGGESAK' **
con <- dbConnect(PostgreSQL(), dbname="planar_development")
rs <- dbSendQuery(con, "select cases.initiated_at as case_date, exchanges.journal_date as exchange_date, cases.kind, rank() OVER (order by initiated_at) from exchanges join cases on case_document_id = cases.document_id where kind = 'Byggesak' and incoming = false")
exchanges <- fetch(rs, n = -1)



# ** CHOP **

exchanges <- subset(exchanges, case_date > as.Date('2001-2-1') & exchange_date > as.Date('2001-2-1'))


options(scipen=6) 

# ** PLOT **


# ** exchanges: small dots **
plot(exchanges_chop$exchange_date, exchanges_chop$case_date, col=rgb(0,0,0,90,maxColorValue=255), cex=0.06, pch=16,
axes=TRUE, main="Saksgang", xlab="", ylab="")

# ** exchanges: small dots ranked **
plot(exchanges$case_date, exchanges$rank, col=rgb(0,0,0,90,maxColorValue=255), cex=0.06, pch=16,
axes=TRUE, main="Saksgang", xlab="", ylab="")





# ** exchanges: colored dots varying cols **
plot(exchanges_chop$exchange_date, exchanges_chop$case_date, col=match(exchanges_chop$kind, kinds), cex=0.06 + (match(exchanges_2010$kind, kinds)/15), pch=16,
axes=TRUE, main="Saksgang", xlab="", ylab="")
legend("topleft", inset=.05,
  	 kinds, fill=nice_cols, horiz=TRUE)


# ** ranked exchanges: colored dots varying cols **
plot(exchanges$exchange_date, exchanges$rank, col=match(exchanges$kind, kinds), cex=0.06 + (match(exchanges$kind, kinds)/15), pch=16,
axes=TRUE, main="Saksgang", xlab="", ylab="")
legend("topleft", inset=.05,
  	 kinds, fill=nice_cols, horiz=TRUE)



# ** plot a subset **

exchanges_2010 <- subset(exchanges, case_date > as.Date('2010-1-1') & exchange_date > as.Date('2010-1-1'))

plot(exchanges_2010$exchange_date, exchanges_2010$case_date, col=match(exchanges_2010$kind, kinds), cex=0.1 + (match(exchanges_2010$kind, kinds)/10), pch=16, axes=TRUE, main="Saksgang", xlab="", ylab="")

legend("topleft", inset=.05,
  	 kinds, fill=nice_cols, horiz=TRUE)

# ggplot 2


p <- ggplot(exchanges_chop, aes(exchange_date, case_date))
p + geom_point() 
