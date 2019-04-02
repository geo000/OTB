/*
 * Copyright (C) 2005-2019 Centre National d'Etudes Spatiales (CNES)
 *
 * This file is part of Orfeo Toolbox
 *
 *     https://www.orfeo-toolbox.org/
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "otbWrapperQtWidgetMainWindow.h"

#include <QtWidgets>
#include "otbWrapperQtWidgetView.h"

#include "ui_appmainwindow.h"

namespace otb
{
namespace Wrapper
{

QtMainWindow::QtMainWindow(Application::Pointer app, QtWidgetView* gui, QWidget* parent) :
    QMainWindow(parent),
    ui(new Ui::AppMainWindow),
    gui(gui),
    m_IsRunning(false)
{
  ui->setupUi(this);
  this->setWindowTitle(QString(app->GetName()).append(" - OTB ").append(OTB_VERSION_STRING));

  // Set the given application view widget
  gui->setParent(this);
  ui->scrollArea->setWidget(gui);

  // Connect menu buttons
  connect(ui->actionQuit, &QAction::triggered, this, &QMainWindow::close);
  const auto url = std::string("https://www.orfeo-toolbox.org/CookBook/Applications/app_") + app->GetName() + std::string(".html");
  connect(ui->actionDocumentation, &QAction::triggered, this, [=] { QDesktopServices::openUrl(QUrl(QString::fromStdString(url))); });

  // Setup execute / cancel button
  ui->executeButton->setDefault(true);
  ui->executeButton->setEnabled(false);
  ui->executeButton->setText(QObject::tr("Execute"));

  connect(gui->GetModel(), &QtWidgetModel::SetApplicationReady, ui->executeButton, &QPushButton::setEnabled);
  connect(this, &QtMainWindow::ExecuteAndWriteOutput, gui->GetModel(), &QtWidgetModel::ExecuteAndWriteOutputSlot);
  connect(this, &QtMainWindow::Stop, gui->GetModel(), &QtWidgetModel::Stop);

  connect( gui->GetModel(), &QtWidgetModel::SetApplicationReady, this, &QtMainWindow::UpdateMessageAfterApplicationReady );
  connect( gui->GetModel(), &QtWidgetModel::SetProgressReportDone, this, &QtMainWindow::UpdateMessageAfterExecution );

  // Status bar and message default text
  ui->statusBar->showMessage(tr("Select parameters"));
  ui->message->setText("");

  // Setup the progress bar to observe the model
  ui->progressBar->SetModel(gui->GetModel());

  connect(ui->progressBar, &QtWidgetSimpleProgressReport::SetText, ui->message, &QLabel::setText);
}

void QtMainWindow::UpdateMessageAfterApplicationReady( bool val )
{
  if (!m_IsRunning)
  {
    if (val == true)
    {
      ui->statusBar->showMessage(tr("Ready to run"));
    }
    else
    {
      ui->statusBar->showMessage(tr("Select parameters"));
    }
  }
}

void QtMainWindow::UpdateMessageAfterExecution(int status)
{
  if (status >= 0)
  {
    ui->statusBar->showMessage(tr("Done"));
  }
  else
  {
    ui->statusBar->showMessage(tr("Failed!"));
  }
  ui->executeButton->setText(tr("Execute"));
  m_IsRunning = false;
}

void QtMainWindow::on_executeButton_clicked()
{
  if (m_IsRunning)
  {
    ui->statusBar->showMessage(tr("Cancelling..."));
    emit Stop();
  }
  else
  {
    gui->BeforeExecuteButtonClicked();
    m_IsRunning = true;
    ui->statusBar->showMessage(tr("Running..."));
    ui->executeButton->setText(tr("Cancel"));
    emit ExecuteAndWriteOutput();
  }
}

QtMainWindow::~QtMainWindow()
{
  delete ui;
}

otb::Wrapper::QtWidgetView* QtMainWindow::Gui() const
{
  return gui;
}

void QtMainWindow::UnhandledException(QString message)
{
  gui->UnhandledException(message);
}

} // namespace Wrapper
} // namespace otb
