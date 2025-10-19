# 🏦 Bank Management System — Oracle SQL Project

A complete **banking database system** developed using **Oracle SQL and PL/SQL**.  
This project demonstrates complex database logic, automation, and data integrity control — all designed as part of university coursework in Software Engineering.

---

## 📚 Features

- 🧩 **Full relational schema**: Departments, Employees, Clients, Accounts, and Relations.
- ⚙️ **Triggers** for employee transfers, client status updates, and account tracking.
- 🧠 **Stored Procedures** for:
  - CRUD operations (Clients, Accounts, Employees)
  - Money transfers (with and without currency conversion)
  - Automatic VIP client status assignment
- 🔐 **User Management System**:
  - Registration & Login using `DBMS_CRYPTO`
  - Archiving inactive users automatically
  - Password update notifications
- ⏰ **Automated Jobs** with `DBMS_SCHEDULER`
- 💾 **Data consistency & error handling** with custom PL/SQL logic

---

## 🧱 Project Structure

| File | Description |
|------|--------------|
| `01_database_schema.sql` | Core tables, constraints, and initial data. |
| `02_triggers_and_procedures.sql` | Triggers, procedures, and business logic. |
| `03_app_user_management.sql` | Packages for user management and scheduled jobs. |

---

## ⚙️ Technologies Used
- Oracle Database 21c  
- PL/SQL  
- DBMS_SCHEDULER  
- DBMS_CRYPTO  
- SQL Developer  

---

## 🚀 How to Run
1. Open the scripts in **Oracle SQL Developer** or SQL*Plus.  
2. Execute them **in this order**:
   - `01_database_schema.sql`
   - `02_triggers_and_procedures.sql`
   - `03_app_user_management.sql`
3. Review the example queries and anonymous blocks at the end of each script.

---

## 📈 Example Scenarios
- ✅ Add and update clients or accounts via stored procedures.  
- 💸 Transfer money between accounts (with automatic currency conversion).  
- 🕵️ Track employee movements and status changes.  
- 🧹 Archive inactive users automatically every 24 hours.  

---

## 👨‍💻 Author

**Vladyslav Lytvynenko**  
🎓 3rd-year Software Engineering student at the University of Paisii Hilendarski, Bulgaria  
📧 [vladlit.vinenko2909@gmail.com](mailto:vladlit.vinenko2909@gmail.com)  
🔗 [LinkedIn](https://www.linkedin.com/in/vladyslav-lytvynenko-7448a8299) • [GitHub](https://github.com/VladyslavLitv)

---

⭐ If you like this project, give it a **star** on GitHub — it really helps!
