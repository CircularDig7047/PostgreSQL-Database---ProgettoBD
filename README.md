# 🍕 TooGood@Uni - Database Systems Project

University project focusing on the design and implementation of a relational database.

**TooGood@Uni** is a database for a university-oriented platform (inspired by "Too Good To Go"). It manages anti-waste food offers provided by affiliated vendors (cafeterias, bars) and allows students to book them at specific pickup points across university campuses.

## 🛠️ Technologies Used

* **RDBMS:** PostgreSQL
* **Languages:** SQL, PL/pgSQL
* **Database Design:** E/R Modeling, Normalization (BCNF/3NF), Redundancy Analysis
* **Optimization:** B-Tree & Hash Indexes, Query Execution Plan Analysis (`EXPLAIN ANALYZE`)

## 🗂️ Repository Contents

This repository contains the SQL scripts required for the creation, population, and optimization of the database, divided into the following phases:

### 1. Schema Implementation & Business Logic (`ParteII.sql`)

* **DDL:** Creation of the `toogoodatuni` schema with associated integrity constraints (`CHECK`, `FOREIGN KEY`).
* **DML:** Basic data population for operational testing.
* **Views:** Aggregated views (e.g., vendor sales statistics and ratings).
* **Queries:** Complex queries (set operations, relational division, correlated subqueries).
* **Functions & Triggers (PL/pgSQL):**
  * Automated management and validation of order creation.
  * Dynamic calculation of the total economic savings accumulated by students.
  * Triggers for cross-checking consistency among offers, conventions, and campus locations.
  * Triggers for the automatic penalization of student accounts in case of repeated "no-shows".

### 2. Physical Design & Security (`ParteIII-a.sql` & `ParteIII-b.sql`)

* **Optimization:** Scripts for workload testing and the creation of physical **Indexes** (B-Tree, Hash, composite, and clustered indexes) to significantly reduce query execution times.
* **Security:** Definition of the role hierarchy (`Administrator`, `Collaborator`, `Vendor Representative`, `Student`) and related Role-Based Access Control (RBAC) policies using `GRANT`/`REVOKE`.
* **Stress-Test:** "In the large" data population with massive data generation (e.g., 10,000 users, 30,000 orders) to verify and compare execution plans (e.g., Seq Scan vs. Bitmap Index Scan).
